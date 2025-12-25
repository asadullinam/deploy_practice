# Быстрая инструкция по проверке проекта

## Текущее состояние

Проект полностью настроен и работает в локальном minikube кластере.

### Что запущено:

**Кластер:**
- Minikube v1.37.0 на qemu2 driver
- Kubernetes v1.32.0

**Flux система (namespace: flux-system):**
- source-controller - управление источниками (Git, Helm, OCI)
- kustomize-controller - применение Kustomize манифестов
- helm-controller - управление Helm releases
- notification-controller - уведомления и webhooks

**Приложение (namespace: fake-service):**
- Deployment: 2 реплики fake-service
- Services: fake-service, fake-service-metrics
- Приложение: FastAPI с Prometheus метриками

**Мониторинг (namespace: monitoring):**
- Prometheus - сбор метрик
- Grafana - визуализация
- Alertmanager - управление алертами
- Loki - хранение логов
- Promtail - сбор логов
- Node Exporter - метрики нод
- Kube State Metrics - метрики Kubernetes объектов

## Как проверить что все работает

### 1. Проверка кластера (30 секунд)

```bash
# Статус кластера
minikube status

# Должен показать:
# host: Running
# kubelet: Running
# apiserver: Running
```

### 2. Проверка подов (30 секунд)

```bash
# Все поды должны быть Running
kubectl get pods -A

# Или по namespace
kubectl get pods -n flux-system     # 4 пода
kubectl get pods -n fake-service    # 2 пода
kubectl get pods -n monitoring      # 8+ подов
```

### 3. Доступ к сервисам (1 минута)

```bash
# Запустить port-forwards
./port-forward.sh

# Откроются:
# - fake-service на localhost:8000
# - Grafana на localhost:3000
# - Prometheus на localhost:9090
```

### 4. Тест API (2 минуты)

```bash
# Health check
curl http://localhost:8000/health
# Ожидается: {"status":"healthy","timestamp":...}

# Создать пользователя
curl -X POST "http://localhost:8000/users?name=Test&email=test@example.com"

# Получить пользователей
curl http://localhost:8000/users
# Ожидается: {"users":[...],"count":1}

# Проверить метрики
curl http://localhost:8000/metrics | grep http_requests_total
# Ожидается: http_requests_total{method="GET",endpoint="/users",status="200"} X
```

### 5. Проверка Grafana (2 минуты)

1. Открыть http://localhost:3000
2. Логин: admin, Пароль: admin
3. Dashboards → Browse
4. Открыть "Kubernetes / Compute Resources / Namespace (Pods)"
5. Выбрать namespace: fake-service
6. Должны быть видны графики CPU/Memory

### 6. Проверка Prometheus (2 минуты)

1. Открыть http://localhost:9090
2. Status → Targets
3. Проверить что endpoints в состоянии UP
4. Graph → ввести: `http_requests_total`
5. Execute → должны появиться данные

### 7. Проверка логов в Loki (2 минуты)

1. Grafana → Explore
2. Datasource: Loki
3. Запрос: `{namespace="fake-service"}`
4. Run query → должны появиться логи

## Генерация нагрузки для демонстрации

```bash
# Запустить в отдельном терминале
while true; do 
  curl -s http://localhost:8000/users > /dev/null
  curl -s -X POST "http://localhost:8000/users?name=User$RANDOM&email=user$RANDOM@test.com" > /dev/null
  sleep 1
done
```

После 1-2 минут:
- В Prometheus должны появиться данные по запросам
- В Grafana графики должны показать активность
- В Loki должны появиться новые логи

## Полезные команды

```bash
# Логи приложения
kubectl logs -n fake-service -l app=fake-service -f

# Статус Flux
flux check
flux get all

# Рестарт приложения
kubectl rollout restart -n fake-service deployment/fake-service

# Пересобрать образ
eval $(minikube docker-env)
docker build --platform linux/arm64 -t fake-service:latest .
kubectl rollout restart -n fake-service deployment/fake-service

# Остановить port-forwards
pkill -f "kubectl port-forward"
```

## Что проверить преподавателю

### Обязательные пункты:

1. **Dockerfile**
   - Файл: `Dockerfile`
   - Проверка: корректно ли собирается образ Python приложения

2. **GitHub Action**
   - Файл: `.github/workflows/docker-build.yml`
   - Проверка: настроена ли сборка и push в registry

3. **Minikube + Flux**
   - Команда: `minikube status && flux check`
   - Проверка: кластер работает, Flux установлен

4. **Kubernetes манифесты**
   - Файлы: `k8s/*.yaml`
   - Команда: `kubectl get all -n fake-service`
   - Проверка: приложение задеплоено и работает

5. **Мониторинг**
   - Команда: `kubectl get pods -n monitoring`
   - Grafana: http://localhost:3000
   - Проверка: Prometheus, Loki, Grafana работают

### Дополнительные пункты:

6. **Метрики Prometheus**
   - URL: http://localhost:8000/metrics
   - Проверка: метрики экспортируются

7. **Flux GitOps**
   - Команда: `flux get sources git`
   - Проверка: настроена ли интеграция с Git

8. **Логи**
   - Loki в Grafana → Explore
   - Проверка: логи собираются

## Если что-то не работает

### Поды не запускаются

```bash
kubectl describe pod POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE
```

### Port-forward не работает

```bash
pkill -f "kubectl port-forward"
./port-forward.sh
```

### Метрики не появляются

```bash
# Проверить что приложение работает
curl http://localhost:8000/health

# Проверить ServiceMonitor
kubectl get servicemonitor -n fake-service

# Проверить targets в Prometheus
# Status → Targets
```

### Flux не работает

```bash
flux check
flux logs --level=error
kubectl get pods -n flux-system
```

## Время выполнения проверки

- Быстрая проверка: 5-7 минут
- Полная проверка: 15-20 минут
- С демонстрацией нагрузки: 25-30 минут

