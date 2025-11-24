"""add memory, schedule and device metadata models

Revision ID: 7b2f4a1c9e14
Revises: 29ada689f6dd
Create Date: 2025-11-24 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '7b2f4a1c9e14'
down_revision = '29ada689f6dd'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'memoryentry',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('user_id', sa.String(), index=True, nullable=True),
        sa.Column('entry_type', sa.String(), nullable=True),
        sa.Column('data', sa.JSON(), nullable=False),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=False),
    )

    op.create_table(
        'schedulejob',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('cron', sa.String(), nullable=True),
        sa.Column('next_run', sa.TIMESTAMP(), nullable=True),
        sa.Column('enabled', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('data', sa.JSON(), nullable=False),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=False),
    )

    op.create_table(
        'devicemetadata',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('device_id', sa.String(), index=True, nullable=False),
        sa.Column('device_type', sa.String(), nullable=True),
        sa.Column('location', sa.String(), nullable=True),
        sa.Column('metadata', sa.JSON(), nullable=False),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table('devicemetadata')
    op.drop_table('schedulejob')
    op.drop_table('memoryentry')
