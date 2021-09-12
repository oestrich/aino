#/bin/bash

set -ex

export DOCKER_BUILDKIT=1
sha=$(git rev-parse HEAD)

docker build -f Dockerfile.site -t oestrich/ainoweb.dev:${sha} .
docker push oestrich/ainoweb.dev:${sha}

cd helm
helm upgrade ainoweb static/ --namespace static-sites -f values.yml --set image.tag=${sha}
