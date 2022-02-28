# start from alpine
FROM alpine:3.15

# add bash, curl, wget, other networking tools
RUN apk update && apk add bash bind-tools curl wget busybox-extras redis mysql-client python3 py3-pip

# install aws tools
RUN pip install awscli

# copy utilities and add to PATH
COPY utils/ /utils/
ENV PATH="/utils:${PATH}"

# cleanup
RUN rm -rf /var/cache/apk/*

# start with bash
CMD /bin/bash
