#!/usr/bin/env bash
# scripts/build-and-push.sh — Build and push images to local k3d registry
# Implements: REQ-K8E-007, REQ-K8E-008, REQ-K8E-016
# Design: docs/specs/k8s-e2e/design.md §3.3

set -euo pipefail

REGISTRY_NAME="${K3D_REGISTRY_NAME:-hexcrawler-registry.localhost}"
REGISTRY_PORT="${K3D_REGISTRY_PORT:-5111}"
REGISTRY="k3d-${REGISTRY_NAME}:${REGISTRY_PORT}"
TAG="${1:-$(git rev-parse --short HEAD)}"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Build & Push Images                    ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Registry: $REGISTRY"
echo "Tag:      $TAG"
echo ""

START_TIME=$(date +%s)

echo "▸ Building crawler image..."
docker build -f infra/docker/Dockerfile \
  -t "${REGISTRY}/hexcrawler:${TAG}" \
  -t "${REGISTRY}/hexcrawler:latest" .
echo "  Pushing crawler image..."
docker push "${REGISTRY}/hexcrawler:${TAG}"
docker push "${REGISTRY}/hexcrawler:latest"
echo "  ✓ hexcrawler:${TAG}"
echo ""

echo "▸ Building web simulator image..."
docker build -f infra/docker/Dockerfile.web-simulator \
  -t "${REGISTRY}/hexcrawler-web-simulator:${TAG}" \
  -t "${REGISTRY}/hexcrawler-web-simulator:latest" .
echo "  Pushing web simulator image..."
docker push "${REGISTRY}/hexcrawler-web-simulator:${TAG}"
docker push "${REGISTRY}/hexcrawler-web-simulator:latest"
echo "  ✓ hexcrawler-web-simulator:${TAG}"
echo ""

echo "▸ Building mega simulator image..."
docker build -f infra/docker/Dockerfile.mega-simulator \
  -t "${REGISTRY}/hexcrawler-mega-simulator:${TAG}" \
  -t "${REGISTRY}/hexcrawler-mega-simulator:latest" .
echo "  Pushing mega simulator image..."
docker push "${REGISTRY}/hexcrawler-mega-simulator:${TAG}"
docker push "${REGISTRY}/hexcrawler-mega-simulator:latest"
echo "  ✓ hexcrawler-mega-simulator:${TAG}"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "═══════════════════════════════════════════"
echo "  ✓ All images pushed (${DURATION}s)"
echo "    ${REGISTRY}/hexcrawler:${TAG}"
echo "    ${REGISTRY}/hexcrawler-web-simulator:${TAG}"
echo "    ${REGISTRY}/hexcrawler-mega-simulator:${TAG}"
echo "═══════════════════════════════════════════"
