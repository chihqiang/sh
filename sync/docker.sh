#!/usr/bin/env bash
set -e

# docker login registry.cn-hongkong.aliyuncs.com --username=username -p password
# docker login hkccr.ccs.tencentyun.com --username=username -p password
# curl -sSL https://raw.githubusercontent.com/chihqiang/sh/main/sync/docker.sh | bash

mysql_versions=("5.7" "8.0" "8.1" "8.2" "8.3" "8.4")
mariadb_versions=("10.5" "10.6" "10.11" "11.4" "11.7")
redis_versions=("6.2" "7.4")

function sync(){
    local from_image=$1
    local target_image=$2
    echo "Downloading ${from_image}"
    docker pull ${from_image}

    echo "rename ${from_image} -> ${target_image}"
    docker tag ${from_image} ${target_image}

    echo "push ${target_image}"
    docker push ${target_image}

    echo "deldete ${target_image}"
    docker rmi ${from_image}

    echo "deldete ${target_image}"
    docker rmi ${target_image}
}

function sync_mysql() {
    local hub=$1
    for version in "${mysql_versions[@]}"
    do
        local from_image="mysql:${version}"
        local target_image="${hub}:mysql-${version}"
        sync $from_image $target_image
    done
}

function sync_redis() {
    local hub=$1
    for version in "${redis_versions[@]}"
    do
        local from_image="redis:${version}"
        local target_image="${hub}:redis-${version}"
        sync $from_image $target_image
    done
}

function sync_mariadb() {
    local hub=$1
    for version in "${mariadb_versions[@]}"
    do
        local from_image="mariadb:${version}"
        local target_image="${hub}:mariadb-${version}"
        sync $from_image $target_image
    done
}


sync_mysql registry.cn-hongkong.aliyuncs.com/buildx/hub
sync_mysql hkccr.ccs.tencentyun.com/buildx/hub

sync_redis registry.cn-hongkong.aliyuncs.com/buildx/hub
sync_redis hkccr.ccs.tencentyun.com/buildx/hub

sync_mariadb registry.cn-hongkong.aliyuncs.com/buildx/hub
sync_mariadb hkccr.ccs.tencentyun.com/buildx/hub


sync zhiqiangwang/spug:latest registry.cn-hongkong.aliyuncs.com/buildx/soft:spug
sync zhiqiangwang/spug:latest hkccr.ccs.tencentyun.com/buildx/soft:spug
