# Fake Service - GitOps Project

Демонстрационный проект с полным CI/CD pipeline, GitOps через Flux и мониторингом.

## Компоненты проекта

**Приложение:**
- Python FastAPI сервис с REST API
- Prometheus метрики
- Health checks
- Имитация работы с БД, внешними API, кэшированием

**Инфраструктура:**
- Kubernetes (minikube)
- Flux для GitOps
- Prometheus для метрик
- Loki для логов
- Grafana для визуализации

**CI/CD:**
- GitHub Actions для сборки образов
- Автоматический деплой через Flux
- Автоматическое обновление образов

## Быстрый старт

### Предварительные требования

- Docker Desktop
- minikube
- kubectl
- flux CLI

### Установка

```bash
# Запустить автоматическую установку
./setup-cluster.sh
```

Скрипт выполнит:
1. Установку необходимых инструментов
2. Создание minikube кластера
3. Установку Flux
4. Создание namespaces

### Деплой приложения

```bash
# Собрать образ
eval $(minikube docker-env)
docker build --platform linux/arm64 -t fake-service:latest .

# Применить манифесты
kubectl create namespace fake-service
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### Установка мониторинга

```bash
kubectl create namespace monitoring
kubectl apply -f monitoring/helm-repositories.yaml
kubectl apply -f monitoring/prometheus-stack.yaml
kubectl apply -f monitoring/loki.yaml
```

### Доступ к сервисам

```bash
# Запустить port-forwards
./port-forward.sh
```

Сервисы доступны:
- Fake Service: http://localhost:8000
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090

## API Endpoints

```bash
# Health check
GET /health

# Информация о сервисе
GET /

# Пользователи
GET /users
POST /users?name=NAME&email=EMAIL
GET /users/{id}

# Заказы
GET /orders
POST /orders?user_id=ID&product=PRODUCT&amount=AMOUNT
GET /orders/{id}

# Статистика
GET /stats

# Метрики Prometheus
GET /metrics
```

## Метрики

Приложение экспортирует метрики:

- `http_requests_total` - количество HTTP запросов
- `http_request_duration_seconds` - длительность запросов
- `db_query_duration_seconds` - длительность DB запросов
- `external_api_calls_total` - вызовы внешних API
- `active_users` - активные пользователи
- `cache_hits_total` / `cache_misses_total` - статистика кэша

## Тестирование

```bash
# Простой тест
curl http://localhost:8000/health

# Создать пользователя
curl -X POST "http://localhost:8000/users?name=Test&email=test@example.com"

# Получить пользователей
curl http://localhost:8000/users

# Посмотреть метрики
curl http://localhost:8000/metrics
```

### Генерация нагрузки

```bash
while true; do
  curl -s http://localhost:8000/users > /dev/null
  curl -s -X POST "http://localhost:8000/users?name=User$RANDOM&email=user$RANDOM@test.com" > /dev/null
  sleep 1
done
```

## Мониторинг

### Grafana

1. Открыть http://localhost:3000
2. Логин: admin / admin
3. Dashboards → Browse
4. Доступные дашборды:
   - Kubernetes / Compute Resources
   - Kubernetes / Networking

### Prometheus

1. Открыть http://localhost:9090
2. Примеры запросов:

```promql
# HTTP request rate
rate(http_requests_total{namespace="fake-service"}[5m])

# Request duration p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Active users
active_users

# Cache hit rate
rate(cache_hits_total[5m]) / (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m]))
```

### Loki (логи)

В Grafana → Explore → Loki:

```logql
# Все логи fake-service
{namespace="fake-service"}

# Только ошибки
{namespace="fake-service"} |= "ERROR"

# Созданные пользователи
{namespace="fake-service"} |~ "User created"
```

## Структура проекта

```
.
├── app.py                      # FastAPI приложение
├── Dockerfile                  # Docker образ
├── requirements.txt            # Python зависимости
├── setup-cluster.sh            # Установка кластера
├── port-forward.sh             # Быстрый доступ к сервисам
├── .github/workflows/
│   └── docker-build.yml        # CI/CD pipeline
├── k8s/                        # Kubernetes манифесты
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── servicemonitor.yaml
│   └── kustomization.yaml
├── flux-config/                # Flux конфигурация
│   ├── git-repository.yaml
│   ├── kustomization.yaml
│   └── image-automation.yaml
└── monitoring/                 # Мониторинг стек
    ├── prometheus-stack.yaml
    ├── loki.yaml
    └── grafana-dashboard.yaml
```

## Flux GitOps

### Подключение GitHub репозитория

См. подробную инструкцию в `GITHUB_SETUP.md`

```bash
# Обновить flux-config/git-repository.yaml с вашим repo
# Применить конфигурацию
kubectl apply -f flux-config/git-repository.yaml
kubectl apply -f flux-config/kustomization.yaml

# Проверить статус
flux get sources git
flux get kustomizations
```

### Автоматический деплой

После настройки Flux:
1. Изменения в Git автоматически применяются в кластер
2. Новые версии образов автоматически деплоятся
3. История изменений хранится в Git

## Полезные команды

```bash
# Проверка статуса
kubectl get pods -A
flux get all

# Логи приложения
kubectl logs -n fake-service -l app=fake-service -f

# Рестарт приложения
kubectl rollout restart -n fake-service deployment/fake-service

# Пересборка образа
eval $(minikube docker-env)
docker build --platform linux/arm64 -t fake-service:latest .
kubectl rollout restart -n fake-service deployment/fake-service

# Остановка кластера
minikube stop

# Удаление кластера
minikube delete
```

## Документация

- `QUICKSTART.md` - быстрая инструкция по проверке
- `TESTING.md` - подробное тестирование
- `GITHUB_SETUP.md` - настройка GitHub интеграции
- `PROJECT_STATUS.md` - статус проекта
- `SETUP.md` - полная документация

## Особенности реализации

### qemu2 Driver

Проект использует qemu2 driver для minikube:
- Стабильная работа на Apple Silicon
- Не требует Docker Desktop
- Не поддерживает minikube service/tunnel (используется kubectl port-forward)

### Сборка образов

Образы собираются внутри minikube Docker окружения:

```bash
eval $(minikube docker-env)
docker build --platform linux/arm64 -t fake-service:latest .
```

### GitHub Actions

Workflow автоматически:
- Собирает образ при push в main
- Пушит в GitHub Container Registry
- Создает теги: latest, SHA, semver
- Поддерживает multi-platform (amd64/arm64)

## Troubleshooting

### Поды не запускаются

```bash
kubectl describe pod POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE
```

### Метрики не собираются

```bash
kubectl get servicemonitor -n fake-service
# Проверить targets в Prometheus: Status → Targets
```

### Flux не синхронизируется

```bash
flux check
flux logs --level=error
flux reconcile source git flux-system
```

## Лицензия

MIT


## Автоматический деплой

Flux настроен на автоматическую синхронизацию с GitHub каждые 1 минуту. При пуше изменений в репозиторий:
- Flux обнаружит изменения в течение 1 минуты
- Автоматически применит обновленные манифесты
- Kubernetes развернет новую версию приложения

Проверка статуса: `flux get all -A`
