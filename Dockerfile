FROM centos:centos7 as temp

ENV java_version=11.0.12 \
    zulu_version=11.50.19 \
    java_hash=b8e8a63b79bc312aa90f3558edbea59e71495ef1a9c340e38900dd28a1c579f3 \
    jetty_version=9.4.43.v20210629 \
    jetty_hash=a909e2966522c6b7bd5a8632a8086dfd3d0d277d \
    idp_version=4.1.4 \
    idp_hash=65429f547a7854b30713d86ba5901ca718eae91efb3e618ee11108be59bf8a29 \
    dta_hash=444fe792c90e313dbbd1fddf879032b2c7d14012 \
    slf4j_version=1.7.25 \
    slf4j_hash=da76ca59f6a57ee3102f8f9bd9cee742973efa8a \
    logback_version=1.2.3 \
    logback_classic_hash=7c4f3c474fb2c041d8028740440937705ebb473a \
    logback_core_hash=864344400c3d4d92dfeb0a305dc87d953677c03c \
    logback_access_hash=e8a841cb796f6423c7afd8738df6e0e4052bf24a

ENV JETTY_HOME=/opt/jetty-home \
    JETTY_BASE=/opt/shib-jetty-base \
    PATH=$PATH:$JRE_HOME/bin

RUN yum -y update \
    && yum -y install wget tar which \
    && yum -y clean all

# Download Java, verify the hash, and install
RUN wget -q http://cdn.azul.com/zulu/bin/zulu$zulu_version-ca-jdk$java_version-linux_x64.tar.gz \
    && echo "$java_hash  zulu$zulu_version-ca-jdk$java_version-linux_x64.tar.gz" | sha256sum -c - \
    && tar -zxvf zulu$zulu_version-ca-jdk$java_version-linux_x64.tar.gz -C /opt \
    && ln -s /opt/zulu$zulu_version-ca-jdk$java_version-linux_x64/ /opt/jre-home

# Download Jetty, verify the hash, and install, initialize a new base
RUN wget -q https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-distribution/$jetty_version/jetty-distribution-$jetty_version.tar.gz \
    && echo "$jetty_hash  jetty-distribution-$jetty_version.tar.gz" | sha1sum -c - \
    && tar -zxvf jetty-distribution-$jetty_version.tar.gz -C /opt \
    && ln -s /opt/jetty-distribution-$jetty_version/ /opt/jetty-home

# Config Jetty
RUN mkdir -p /opt/shib-jetty-base/modules /opt/shib-jetty-base/lib/ext  /opt/shib-jetty-base/lib/logging /opt/shib-jetty-base/resources \
    && cd /opt/shib-jetty-base \
    && touch start.ini \
    && /opt/jre-home/bin/java -jar ../jetty-home/start.jar --add-to-startd=http,https,deploy,ext,annotations,jstl,rewrite

# Download Shibboleth IdP, verify the hash, and install
RUN wget -q https://shibboleth.net/downloads/identity-provider/$idp_version/shibboleth-identity-provider-$idp_version.tar.gz \
    && echo "$idp_hash  shibboleth-identity-provider-$idp_version.tar.gz" | sha256sum -c - \
    && tar -zxvf  shibboleth-identity-provider-$idp_version.tar.gz -C /opt \
    && ln -s /opt/shibboleth-identity-provider-$idp_version/ /opt/shibboleth-idp

# Download the library to allow SOAP Endpoints, verify the hash, and place
RUN wget -q https://build.shibboleth.net/nexus/content/repositories/releases/net/shibboleth/utilities/jetty9/jetty94-dta-ssl/1.0.0/jetty94-dta-ssl-1.0.0.jar \
    && echo "$dta_hash  jetty94-dta-ssl-1.0.0.jar" | sha1sum -c - \
    && mv jetty94-dta-ssl-1.0.0.jar /opt/shib-jetty-base/lib/ext/

# Download the slf4j library for Jetty logging, verify the hash, and place
RUN wget -q https://repo1.maven.org/maven2/org/slf4j/slf4j-api/$slf4j_version/slf4j-api-$slf4j_version.jar \
    && echo "$slf4j_hash  slf4j-api-$slf4j_version.jar" | sha1sum -c - \
    && mv slf4j-api-$slf4j_version.jar /opt/shib-jetty-base/lib/logging/

# Download the logback_classic library for Jetty logging, verify the hash, and place
RUN wget -q https://repo1.maven.org/maven2/ch/qos/logback/logback-classic/$logback_version/logback-classic-$logback_version.jar \
    && echo "$logback_classic_hash  logback-classic-$logback_version.jar" | sha1sum -c - \
    && mv logback-classic-$logback_version.jar /opt/shib-jetty-base/lib/logging/

# Download the logback-core library for Jetty logging, verify the hash, and place
RUN wget -q https://repo1.maven.org/maven2/ch/qos/logback/logback-core/$logback_version/logback-core-$logback_version.jar \
    && echo "$logback_core_hash logback-core-$logback_version.jar" | sha1sum -c - \
    && mv logback-core-$logback_version.jar /opt/shib-jetty-base/lib/logging/

# Download the logback-access library for Jetty logging, verify the hash, and place
RUN wget -q https://repo1.maven.org/maven2/ch/qos/logback/logback-access/$logback_version/logback-access-$logback_version.jar \
    && echo "$logback_access_hash logback-access-$logback_version.jar" | sha1sum -c - \
    && mv logback-access-$logback_version.jar /opt/shib-jetty-base/lib/logging/

# Setting owner ownership and permissions on new items in this command
RUN useradd jetty -U -s /bin/false \
    && chown -R root:jetty /opt \
    && chmod -R 640 /opt \
    && chmod 750 /opt/jre-home/bin/java

COPY opt/shib-jetty-base/ /opt/shib-jetty-base/
COPY opt/shibboleth-idp/ /opt/shibboleth-idp/

# Setting owner ownership and permissions on new items from the COPY command
RUN mkdir /opt/shib-jetty-base/logs \
    && chown -R root:jetty /opt/shib-jetty-base \
    && chmod -R 640 /opt/shib-jetty-base \
    && chmod -R 750 /opt/shibboleth-idp/bin
    
FROM centos:centos7

LABEL maintainer="Unicon, Inc."\
      idp.java.version="8.0.212" \
      idp.jetty.version="9.3.27.v20190418" \
      idp.version="3.4.3"

ENV JETTY_HOME=/opt/jetty-home \
    JETTY_BASE=/opt/shib-jetty-base \
    JETTY_MAX_HEAP=2048m \
    JETTY_BROWSER_SSL_KEYSTORE_PASSWORD=changeme \
    JETTY_BACKCHANNEL_SSL_KEYSTORE_PASSWORD=changeme \
    PATH=$PATH:$JRE_HOME/bin

RUN yum -y update \
    && yum -y install which \
    && yum -y clean all

COPY bin/ /usr/local/bin/

RUN useradd jetty -U -s /bin/false \
    && chmod 750 /usr/local/bin/run-jetty.sh /usr/local/bin/init-idp.sh

COPY --from=temp /opt/ /opt/

RUN chmod +x /opt/jetty-home/bin/jetty.sh

# Opening 4443 (browser TLS), 8443 (mutual auth TLS)
EXPOSE 4443 8443

CMD ["run-jetty.sh"]
