import asyncio
import random
import time
from fastapi import FastAPI, HTTPException
from fastapi.responses import PlainTextResponse
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import logging
import uvicorn

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Создаем FastAPI приложение
app = FastAPI(title="Fake Service API", version="1.0.0")

# Prometheus метрики
request_counter = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

request_duration = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

db_query_duration = Histogram(
    'db_query_duration_seconds',
    'Database query duration in seconds',
    ['query_type']
)

external_api_calls = Counter(
    'external_api_calls_total',
    'Total external API calls',
    ['api_name', 'status']
)

active_users = Gauge(
    'active_users',
    'Number of active users'
)

cache_hits = Counter(
    'cache_hits_total',
    'Total cache hits',
    ['cache_name']
)

cache_misses = Counter(
    'cache_misses_total',
    'Total cache misses',
    ['cache_name']
)

# Имитация базы данных
fake_db = {
    "users": [],
    "orders": []
}

# Имитация кэша
fake_cache = {}


async def simulate_db_query(query_type: str, delay: float = None):
    """Имитация запроса к базе данных"""
    if delay is None:
        delay = random.uniform(0.01, 0.1)
    
    with db_query_duration.labels(query_type=query_type).time():
        await asyncio.sleep(delay)
        logger.info(f"DB query executed: {query_type}, duration: {delay:.3f}s")


async def simulate_external_api(api_name: str, success_rate: float = 0.9):
    """Имитация вызова внешнего API"""
    await asyncio.sleep(random.uniform(0.05, 0.3))
    
    if random.random() < success_rate:
        external_api_calls.labels(api_name=api_name, status="success").inc()
        logger.info(f"External API call successful: {api_name}")
        return True
    else:
        external_api_calls.labels(api_name=api_name, status="failure").inc()
        logger.warning(f"External API call failed: {api_name}")
        return False


@app.middleware("http")
async def metrics_middleware(request, call_next):
    """Middleware для сбора метрик"""
    start_time = time.time()
    
    response = await call_next(request)
    
    duration = time.time() - start_time
    request_counter.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    
    request_duration.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)
    
    return response


@app.get("/")
async def root():
    """Главная страница"""
    logger.info("Root endpoint accessed")
    return {
        "message": "Fake Service API",
        "version": "1.0.0",
        "endpoints": [
            "/health",
            "/metrics",
            "/users",
            "/users/{user_id}",
            "/orders",
            "/orders/{order_id}",
            "/stats"
        ]
    }


@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": time.time()}


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return PlainTextResponse(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/users")
async def get_users():
    """Получить список пользователей"""
    # Проверяем кэш
    cache_key = "all_users"
    if cache_key in fake_cache:
        cache_hits.labels(cache_name="users").inc()
        logger.info("Cache hit for users list")
        return fake_cache[cache_key]
    
    cache_misses.labels(cache_name="users").inc()
    
    # Имитация запроса к БД
    await simulate_db_query("SELECT")
    
    # Имитация обновления счетчика активных пользователей
    active_users.set(random.randint(10, 100))
    
    users = fake_db["users"]
    fake_cache[cache_key] = {"users": users, "count": len(users)}
    
    return {"users": users, "count": len(users)}


@app.post("/users")
async def create_user(name: str, email: str):
    """Создать нового пользователя"""
    # Имитация проверки через внешний API
    if not await simulate_external_api("email_validation_service"):
        raise HTTPException(status_code=400, detail="Email validation failed")
    
    # Имитация записи в БД
    await simulate_db_query("INSERT", delay=random.uniform(0.02, 0.15))
    
    user = {
        "id": len(fake_db["users"]) + 1,
        "name": name,
        "email": email,
        "created_at": time.time()
    }
    
    fake_db["users"].append(user)
    
    # Инвалидация кэша
    if "all_users" in fake_cache:
        del fake_cache["all_users"]
    
    logger.info(f"User created: {user}")
    active_users.inc()
    
    return user


@app.get("/users/{user_id}")
async def get_user(user_id: int):
    """Получить пользователя по ID"""
    # Проверяем кэш
    cache_key = f"user_{user_id}"
    if cache_key in fake_cache:
        cache_hits.labels(cache_name="user").inc()
        logger.info(f"Cache hit for user {user_id}")
        return fake_cache[cache_key]
    
    cache_misses.labels(cache_name="user").inc()
    
    # Имитация запроса к БД
    await simulate_db_query("SELECT", delay=random.uniform(0.01, 0.05))
    
    users = [u for u in fake_db["users"] if u["id"] == user_id]
    
    if not users:
        raise HTTPException(status_code=404, detail="User not found")
    
    user = users[0]
    fake_cache[cache_key] = user
    
    return user


@app.get("/orders")
async def get_orders():
    """Получить список заказов"""
    # Имитация сложного запроса к БД с джоинами
    await simulate_db_query("SELECT_WITH_JOIN", delay=random.uniform(0.1, 0.3))
    
    # Имитация вызова внешнего API для получения цен
    await simulate_external_api("pricing_service")
    
    return {"orders": fake_db["orders"], "count": len(fake_db["orders"])}


@app.post("/orders")
async def create_order(user_id: int, product: str, amount: float):
    """Создать новый заказ"""
    # Имитация проверки пользователя
    await simulate_db_query("SELECT", delay=random.uniform(0.01, 0.05))
    
    # Имитация вызова платежного API
    if not await simulate_external_api("payment_gateway", success_rate=0.85):
        raise HTTPException(status_code=503, detail="Payment gateway unavailable")
    
    # Имитация транзакции в БД
    await simulate_db_query("INSERT", delay=random.uniform(0.05, 0.2))
    
    order = {
        "id": len(fake_db["orders"]) + 1,
        "user_id": user_id,
        "product": product,
        "amount": amount,
        "status": "completed",
        "created_at": time.time()
    }
    
    fake_db["orders"].append(order)
    logger.info(f"Order created: {order}")
    
    return order


@app.get("/orders/{order_id}")
async def get_order(order_id: int):
    """Получить заказ по ID"""
    await simulate_db_query("SELECT")
    
    orders = [o for o in fake_db["orders"] if o["id"] == order_id]
    
    if not orders:
        raise HTTPException(status_code=404, detail="Order not found")
    
    return orders[0]


@app.get("/stats")
async def get_stats():
    """Получить статистику сервиса"""
    # Имитация сложных аналитических запросов
    await simulate_db_query("ANALYTICS", delay=random.uniform(0.2, 0.5))
    
    return {
        "total_users": len(fake_db["users"]),
        "total_orders": len(fake_db["orders"]),
        "active_users": random.randint(10, 100),
        "cache_size": len(fake_cache),
        "uptime_seconds": time.time()
    }


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
