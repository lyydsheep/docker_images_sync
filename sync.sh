#!/bin/bash
set -eux


# 检查参数数量是否正确
if [ "$#" -ne 3 ]; then
    echo "错误：脚本需要3个参数 images_file、docker_registry和docker_namespace"
    echo "用法: $0 <images_file> <docker_registry> <docker_namespace>"
    exit 1
fi


IMAGES_FILE=$1
TARGET_REGISTRY=$2
TARGET_NAMESPACE=$3

# 检查文件是否存在
if [ ! -f "$IMAGES_FILE" ]; then
    echo "错误：文件 $IMAGES_FILE 不存在"
    exit 1
fi

failed_count=0
failed_images=""
while IFS= read -r image; do
    # 拉取镜像
    set +e
   docker pull --platform linux/arm64 "$image"
    pull_status=$?
    if [ $pull_status -ne 0 ]; then
        echo "Error: Failed to pull image $image, continuing..."
        failed_count=$((failed_count + 1))
        failed_images="${failed_images} ${image}"
        continue
    fi

    name=$(echo "${image}" | cut -d '/' -f2)
    tag=$(echo "${name}" | cut -d ':' -f2)
    targetFullName=${TARGET_REGISTRY}/${TARGET_NAMESPACE}/${name}

    # 打阿里云的tag
    docker tag "${image}" "${targetFullName}"
    tag_status=$?

    # 推送到阿里云
    set +e
    docker push "${targetFullName}"
    push_status=$?
    if [ $push_status -ne 0 ]; then
        echo "Error: Failed to push image $targetFullName, continuing..."
        failed_count=$((failed_count + 1))
        failed_images="${failed_images} ${image}"
        continue
    fi
done < "$IMAGES_FILE"

if [ $failed_count -gt 0 ]; then
    echo "Error: Failed to sync $failed_count images: $failed_images"
    exit 1
fi
echo "Successfully synced all images."