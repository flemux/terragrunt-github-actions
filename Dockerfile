FROM alpine:3 

RUN ["/bin/sh", "-c", "apk add --update --no-cache bash ca-certificates curl git jq openssh"]

# Authorize SSH Host
RUN mkdir -p /ssh/
RUN chmod 0700 /ssh

COPY ["src", "/src/"]

ENTRYPOINT ["/src/main.sh"]
