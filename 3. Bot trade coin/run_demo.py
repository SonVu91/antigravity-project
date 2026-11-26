import asyncio
import logging
from src.main import SentinelApplication

async def main():
    print("=== KHỞI ĐỘNG KIỂM TRA CHU TRÌNH THỰC TẾ ===")
    app = SentinelApplication()
    await app.initialize()
    print("=== CHẠY CHU KỲ THỊ TRƯỜNG THỰC TẾ LẦN 1 ===")
    await app.run_market_cycle()
    print("=== CHẠY CHU KỲ THỊ TRƯỜNG THỰC TẾ LẦN 2 ===")
    await app.run_market_cycle()
    print("=== DỌN DẸP VÀ TẮT HỆ THỐNG ===")
    await app.shutdown()
    print("=== HOÀN TẤT KIỂM THỬ THỰC TẾ 100% THÀNH CÔNG ===")

if __name__ == "__main__":
    asyncio.run(main())
