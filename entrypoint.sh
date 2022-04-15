#!/bin/sh
set -e

main() {
    echo "CICD-START"

    # 检测是否有输入用户名和密码
    if usesBoolean "${ACTIONS_STEP_DEBUG}"; then
        echo "::add-mask::${INPUT_USERNAME}"
        echo "::add-mask::${INPUT_PASSWORD}"
        set -x
    fi

    # 检测是否有输入项目名
    sanitize "${INPUT_NAME}" "name"
    if ! usesBoolean "${INPUT_NO_PUSH}"; then
        sanitize "${INPUT_USERNAME}" "username"
        sanitize "${INPUT_PASSWORD}" "password"
    fi

    registryToLower
    nameToLower
    echo ${INPUT_REGISTRY}
    REGISTRY_NO_PROTOCOL=$(echo "${INPUT_REGISTRY}" | sed -e 's/^https:\/\///g')
    if uses "${INPUT_REGISTRY}" && ! isPartOfTheName "${REGISTRY_NO_PROTOCOL}"; then
        INPUT_NAME="${REGISTRY_NO_PROTOCOL}/${INPUT_NAME}"
    fi

    if uses "${INPUT_TAGS}"; then
        TAGS=$(echo "${INPUT_TAGS}" | sed "s/,/ /g")
    fi

    if uses "${INPUT_USERNAME}" && uses "${INPUT_PASSWORD}"; then
        echo "${INPUT_PASSWORD}" | docker login -u ${INPUT_USERNAME} --password-stdin ${INPUT_REGISTRY}
    fi

    FIRST_TAG=$(echo "${TAGS}" | cut -d ' ' -f1)
    DOCKERNAME="${INPUT_NAME}:${FIRST_TAG}"
    BUILDPARAMS=""
    CONTEXT="."

    build

    if usesBoolean "${INPUT_NO_PUSH}"; then
        if uses "${INPUT_USERNAME}" && uses "${INPUT_PASSWORD}"; then
            docker logout
        fi
        exit 0
    fi

    push

    echo "::set-output name=tag::${FIRST_TAG}"
    DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' ${DOCKERNAME})
    echo "::set-output name=digest::${DIGEST}"

    docker logout
}

# 判断参数是否为空
sanitize() {
    if [ -z "${1}" ]; then
        echo >&2 "Unable to find the ${2}. Did you set with.${2}?"
        exit 1
    fi
}

# registry转小写
registryToLower() {
    INPUT_REGISTRY=$(echo "${INPUT_REGISTRY}" | tr '[A-Z]' '[a-z]')
}

# name转小写
nameToLower() {
    INPUT_NAME=$(echo "${INPUT_NAME}" | tr '[A-Z]' '[a-z]')
}

isPartOfTheName() {
    [ $(echo "${INPUT_NAME}" | sed -e "s/${1}//g") != "${INPUT_NAME}" ]
}

hasCustomTag() {
    [ $(echo "${INPUT_NAME}" | sed -e "s/://g") != "${INPUT_NAME}" ]
}

isGitTag() {
    [ $(echo "${GITHUB_REF}" | sed -e "s/refs\/tags\///g") != "${GITHUB_REF}" ]
}

isPullRequest() {
    [ $(echo "${GITHUB_REF}" | sed -e "s/refs\/pull\///g") != "${GITHUB_REF}" ]
}

uses() {
    [ ! -z "${1}" ]
}

usesBoolean() {
    [ ! -z "${1}" ] && [ "${1}" = "true" ]
}

isSemver() {
    echo "${1}" | grep -Eq '^refs/tags/v?([0-9]+)\.([0-9]+)\.([0-9]+)(-[a-zA-Z]+(\.[0-9]+)?)?$'
}

isPreRelease() {
    echo "${1}" | grep -Eq '-'
}

# 构建配置文件
buildingConfiguration() {
    dockerConfig_1=''
    dockerConfig_2=''
    nginxConfig=''
    for file in $(ls -d App_v[0-9]); do
        version=${file##*App_}
        arg1="WORKDIR /usr/share/nginx/html_${version}\n"
        arg2='RUN rm -rf ./*\n'
        arg3="COPY --from=builder /app/${file}/build .\n"
        # dockerfile
        dockerConfig_1="$dockerConfig_1$arg1$arg2$arg3"
        dockerConfig_2="${dockerConfig_2}WORKDIR /app/${file}\nRUN yarn install && yarn build\n"
        # nginx
        location="\tlocation /${version} {\n"
        talias="\t\talias   /usr/share/nginx/html_${version};\n"
        index="\t\tindex index.html index.htm;\n"
        try_files="\t\ttry_files \$uri \$uri/ /${version}/index.html;\n"
        end="\t\tautoindex on;\n\t}\n"
        nginxConfig="${nginxConfig}${location}${talias}${index}${try_files}${end}"
    done
    sed -i "10a \\${dockerConfig_1}" Dockerfile
    sed -i "5a \\${dockerConfig_2}" Dockerfile
    sed -i "29a \\${nginxConfig}" nginx.conf
}
# dockerfile构建项目
build() {
    cp /Dockerfile ./
    cp /nginx.conf ./nginx.conf
    cp /.dockerignore ./.dockerignore

    buildingConfiguration

    local BUILD_TAGS=""
    for TAG in ${TAGS}; do
        BUILD_TAGS="${BUILD_TAGS}-t ${INPUT_NAME}:${TAG} "
    done
    docker build ${BUILDPARAMS} ${BUILD_TAGS} ${CONTEXT}
}

# 发布包
push() {
    for TAG in ${TAGS}; do
        docker push "${INPUT_NAME}:${TAG}"
    done
}

main
