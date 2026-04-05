import asyncio
from sqlmodel import SQLModel, Field, select
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from typing import Optional
from datetime import datetime, timezone

class SimpleTestModel(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str

async def main():
    print("Creating engine...")
    url = "sqlite+aiosqlite:///test_simple.db"
    engine = create_async_engine(url)
    
    print("Creating tables...")
    async with engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)
    
    print("Opening session...")
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as session:
        print("Adding record...")
        obj = SimpleTestModel(name="Test")
        session.add(obj)
        await session.commit()
        print("Record added.")
        
        print("Querying...")
        res = await session.execute(select(SimpleTestModel))
        results = res.scalars().all()
        print(f"Found {len(results)} records.")
        for r in results:
            print(f" - {r.name}")

    print("Done.")

if __name__ == "__main__":
    asyncio.run(main())
