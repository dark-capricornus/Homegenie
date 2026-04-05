"""add energy history and rules

Revision ID: 8c3f2b1d0e95
Revises: 7b2f4a1c9e14
Create Date: 2026-04-03 23:55:00.000000

"""
from alembic import op
import sqlalchemy as sa
import sqlmodel

# revision identifiers, used by Alembic.
revision = '8c3f2b1d0e95'
down_revision = '7b2f4a1c9e14'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    # Create Energy History table
    if 'energyhistory' not in tables:
        op.create_table(
            'energyhistory',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('device_id', sa.String(), nullable=False),
            sa.Column('power_watts', sa.Float(), nullable=False),
            sa.Column('timestamp', sa.DateTime(), nullable=False),
        )
        op.create_index(op.f('ix_energyhistory_device_id'), 'energyhistory', ['device_id'], unique=False)
        op.create_index(op.f('ix_energyhistory_timestamp'), 'energyhistory', ['timestamp'], unique=False)

    # Create Rule Table
    if 'ruletable' not in tables:
        op.create_table(
            'ruletable',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('name', sa.String(), nullable=False),
            sa.Column('priority', sa.Integer(), nullable=False, server_default='1'),
            sa.Column('enabled', sa.Boolean(), nullable=False, server_default='true'),
            sa.Column('content', sa.JSON(), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=True),
            sa.Column('last_triggered', sa.DateTime(), nullable=True),
        )

    # Create User table
    if 'user' not in tables:
        op.create_table(
            'user',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('username', sa.String(), nullable=False),
            sa.Column('email', sa.String(), nullable=True),
            sa.Column('hashed_password', sa.String(), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False),
        )
        op.create_index(op.f('ix_user_username'), 'user', ['username'], unique=True)
        op.create_index(op.f('ix_user_email'), 'user', ['email'], unique=False)

    # Create Device table (New in v2)
    if 'device' not in tables:
        op.create_table(
            'device',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('device_id', sa.String(), nullable=False),
            sa.Column('name', sa.String(), nullable=True),
            sa.Column('device_type', sa.String(), nullable=True),
            sa.Column('current_state', sa.JSON(), nullable=False),
            sa.Column('intent', sa.JSON(), nullable=False),
            sa.Column('status', sa.String(), nullable=False, server_default='unknown'),
            sa.Column('last_updated', sa.DateTime(), nullable=True),
        )
        op.create_index(op.f('ix_device_device_id'), 'device', ['device_id'], unique=False)



def downgrade() -> None:
    op.drop_index(op.f('ix_device_device_id'), table_name='device')
    op.drop_table('device')
    op.drop_index(op.f('ix_user_email'), table_name='user')
    op.drop_index(op.f('ix_user_username'), table_name='user')
    op.drop_table('user')
    op.drop_table('ruletable')
    op.drop_index(op.f('ix_energyhistory_timestamp'), table_name='energyhistory')
    op.drop_index(op.f('ix_energyhistory_device_id'), table_name='energyhistory')
    op.drop_table('energyhistory')
