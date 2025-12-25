#!/bin/bash

echo "Setting up port forwards for services..."

pkill -f "kubectl port-forward" || true

echo "Starting port-forward for Grafana (port 3000)..."
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
sleep 2

echo "Starting port-forward for Fake Service (port 8000)..."
kubectl port-forward -n fake-service svc/fake-service 8000:8000 &
sleep 2

echo "Starting port-forward for Prometheus (port 9090)..."
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
sleep 2

echo ""
echo "Port forwards are active"
echo ""
echo "Access services:"
echo "  Fake Service:  http://localhost:8000"
echo "  Metrics:       http://localhost:8000/metrics"
echo "  Grafana:       http://localhost:3000 (admin/admin)"
echo "  Prometheus:    http://localhost:9090"
echo ""
echo "To stop all port-forwards:"
echo "   pkill -f 'kubectl port-forward'"
echo ""
echo "Press Ctrl+C to stop this script (port-forwards will continue in background)"
echo ""

wait
