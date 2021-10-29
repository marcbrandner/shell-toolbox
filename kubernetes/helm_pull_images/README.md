`pull_helm_images`
===

Pulls images listed in a typical Helm Values file and exports the to tarballs. Common use cases:
* Pre-pull container images for usage in an air-gapped environment with no connection to contaienr registries.
* Store images on the local device to avoid frequent pulls from container registries due to pull qutoes / rate limiting.

The script works heuristacally and will deliver correct results for YAML files which include commonly used keys to define container images. For example:
* `.[].registry`
* `.[].repository`
* `.[].name`
* `.[].tag`
* `.defaultImageRegistry`
* `.defaultImageRepository`
* `.defaultImageTag`
* `.global.imageRegistry`

That said, this script will work with most, but not all flavors of values file schemas.

# Prerequisites

* `yq` >= `4.0.0`
* `docker` >= `19.03`

# Example Usage

## Example 1

```
# Strimzi Kafka Operator Helm Default Values
wget -O /tmp/values_strimzi.yaml \
    https://raw.githubusercontent.com/strimzi/strimzi-kafka-operator/main/helm-charts/helm3/strimzi-kafka-operator/values.yaml

# Pull images
bash helm_pull_images.sh /tmp/values_strimzi.yaml /tmp
```

Output:
```
Found: yq version 4.6.1
Found: Docker version 20.10.9, build c2ea9bc

1 images to pull:
- quay.io/strimzi/jmxtrans:0.26.0
- quay.io/strimzi/kafka-bridge:0.26.0
- quay.io/strimzi/kafka:0.26.0
- quay.io/strimzi/kaniko-executor:0.26.0
- quay.io/strimzi/maven-builder:0.26.0
- quay.io/strimzi/operator:0.26.0

-- 1 of 6 --
[...]
```

## Example 2

```
# Bitnami PostgreSQL Helm Default Values
wget -O /tmp/values_postgres.yaml \
    https://raw.githubusercontent.com/bitnami/charts/master/bitnami/postgresql/values.yaml

# Pull images
bash helm_pull_images.sh /tmp/values_postgres.yaml /tmp
```

Output:
```
Found: yq version 4.6.1
Found: Docker version 20.10.9, build c2ea9bc

3 images to pull:
- docker.io/bitnami/bitnami-shell:10-debian-10-r220
- docker.io/bitnami/postgres-exporter:0.10.0-debian-10-r88
- docker.io/bitnami/postgresql:11.13.0-debian-10-r60

-- 1 of 3 --
[...]
```

# Roadmap

* __Blacklisting:__ Add script parameter for filtering image names containing a specific pattern