"""expiration des points

Revision ID: 0004
Revises: 0003
Create Date: 2026-09-27 16:01:07.438073
"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = '0004'
down_revision: str | None = '0003'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _backfill_lots() -> None:
    """Calcule les points restants de chaque crédit existant (les dépenses consomment d'abord les plus anciens)."""
    conn = op.get_bind()
    rows = conn.execute(sa.text(
        "SELECT id, account_id, points FROM point_transactions ORDER BY account_id, created_at, id")).fetchall()
    lots: dict[int, list[list[int]]] = {}
    debt: dict[int, int] = {}
    for tx_id, account_id, points in rows:
        account_lots = lots.setdefault(account_id, [])
        if points > 0:
            owed = min(debt.get(account_id, 0), points)
            debt[account_id] = debt.get(account_id, 0) - owed
            account_lots.append([tx_id, points - owed])
        else:
            need = -points
            for lot in account_lots:
                take = min(lot[1], need)
                lot[1] -= take
                need -= take
                if need == 0:
                    break
            debt[account_id] = debt.get(account_id, 0) + need
    balances = dict(conn.execute(sa.text("SELECT id, balance FROM loyalty_accounts")).fetchall())
    for account_id, account_lots in lots.items():
        # Aligne la somme des lots sur le solde réel (données modifiées à la main, arrondis…)
        excess = sum(lot[1] for lot in account_lots) - balances.get(account_id, 0)
        for lot in account_lots:
            if excess <= 0:
                break
            take = min(lot[1], excess)
            lot[1] -= take
            excess -= take
        for tx_id, remaining in account_lots:
            if remaining:
                conn.execute(sa.text("UPDATE point_transactions SET remaining = :r WHERE id = :i"),
                             {"r": remaining, "i": tx_id})


def upgrade() -> None:
    # Nouveau type de mouvement : points expirés
    op.execute("ALTER TYPE transactiontype ADD VALUE IF NOT EXISTS 'expire'")
    op.add_column('centers', sa.Column('points_validity_months', sa.Integer(), nullable=True))
    op.add_column('centers', sa.Column('points_expiry_reminders', sa.JSON(), server_default='[30, 7]', nullable=False))
    op.add_column('point_transactions', sa.Column('remaining', sa.Integer(), server_default='0', nullable=False))
    op.add_column('point_transactions', sa.Column('expires_at', sa.DateTime(), nullable=True))
    op.add_column('point_transactions', sa.Column('expiry_reminded', sa.Integer(), nullable=True))
    op.add_column('point_transactions', sa.Column('consumed', sa.JSON(), nullable=True))
    op.create_index(op.f('ix_point_transactions_expires_at'), 'point_transactions', ['expires_at'], unique=False)
    # Les centres existants restent en « pas d'expiration » : aucun point n'expire après la mise à jour.
    _backfill_lots()


def downgrade() -> None:
    # Note : la valeur d'enum 'expire' reste déclarée (PostgreSQL ne permet pas de la retirer).
    op.drop_index(op.f('ix_point_transactions_expires_at'), table_name='point_transactions')
    op.drop_column('point_transactions', 'consumed')
    op.drop_column('point_transactions', 'expiry_reminded')
    op.drop_column('point_transactions', 'expires_at')
    op.drop_column('point_transactions', 'remaining')
    op.drop_column('centers', 'points_expiry_reminders')
    op.drop_column('centers', 'points_validity_months')
