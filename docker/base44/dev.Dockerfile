# Development runtime image for the Base44 sandbox.
# Contains only runtime tooling (JDK 8 for the Gradle 3.1 wrapper, ffmpeg for the
# optional audio-transcoding feature, curl for the compose healthcheck).
# The application source is bind-mounted at runtime; nothing is baked in.
FROM eclipse-temurin:8-jdk

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg curl \
    && rm -rf /var/lib/apt/lists/*

ENV GRADLE_USER_HOME=/root/.gradle \
    GRADLE_OPTS="-Xmx1024m -Dfile.encoding=UTF-8"

WORKDIR /app/streama
