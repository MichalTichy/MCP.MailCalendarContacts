# syntax=docker/dockerfile:1.7

# Adjutant has no published container release yet. Build its reviewed source at
# an immutable commit and verify the downloaded archive before compiling it.
ARG ADJUTANT_COMMIT=b38414bcfe666ef563d7f87c40b3c44dde096a7b
ARG ADJUTANT_SOURCE_SHA256=bcba01f2a8a55a7441121d112d83ce2be495089c54490d76e52042d4313d5689

FROM mcr.microsoft.com/dotnet/sdk:10.0.301-noble AS build
ARG ADJUTANT_COMMIT
ARG ADJUTANT_SOURCE_SHA256
ADD https://github.com/MarimerLLC/calendar-mcp/archive/${ADJUTANT_COMMIT}.tar.gz /tmp/adjutant.tar.gz
COPY patches/safe-defaults.patch /tmp/safe-defaults.patch
RUN echo "${ADJUTANT_SOURCE_SHA256}  /tmp/adjutant.tar.gz" | sha256sum --check - \
    && apt-get update \
    && apt-get install --yes --no-install-recommends patch \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /source \
    && tar --extract --gzip --file /tmp/adjutant.tar.gz --directory /source --strip-components=1 \
    && patch --directory /source --strip=1 < /tmp/safe-defaults.patch \
    && dotnet publish /source/src/CalendarMcp.HttpServer/CalendarMcp.HttpServer.csproj \
        --configuration Release \
        --output /app/publish \
        /p:UseAppHost=true

FROM mcr.microsoft.com/dotnet/aspnet:10.0.9-noble
WORKDIR /app
RUN groupadd --system adjutant \
    && useradd --system --gid adjutant --home-dir /app --shell /usr/sbin/nologin adjutant \
    && mkdir -p /app/data \
    && chown -R adjutant:adjutant /app
COPY --from=build --chown=adjutant:adjutant /app/publish .
COPY --from=build /source/LICENSE /licenses/adjutant-LICENSE
RUN chmod 0555 /app/CalendarMcp.HttpServer

ENV ASPNETCORE_URLS=http://+:8080 \
    CALENDAR_MCP_CONFIG=/app/data

VOLUME ["/app/data"]
EXPOSE 8080
USER adjutant
ENTRYPOINT ["/app/CalendarMcp.HttpServer"]
