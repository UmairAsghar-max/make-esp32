ARG IDF_VERSION=4.4

FROM espressif/idf:release-v$IDF_VERSION

COPY extra-packages .

RUN apt-get update \
    && apt-get install $(cat extra-packages) -y \
    && rm extra-packages
    