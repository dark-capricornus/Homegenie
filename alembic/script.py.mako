##
## Auto-generated Alembic script template.
##
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '${up_revision}'
down_revision = ${down_revision if down_revision else None}
branch_labels = ${branch_labels if branch_labels else None}
depends_on = ${depends_on if depends_on else None}

${imports if imports else ''}

def upgrade():
    """Write your upgrade migrations here."""
    ${upgrades if upgrades else 'pass'}


def downgrade():
    """Write your downgrade migrations here."""
    ${downgrades if downgrades else 'pass'}
