# SRTla receiver

SRTla receiver with support for multiple streams

- srt from https://github.com/onsmith/srt
- srtla from https://github.com/OpenIRL/srtla
- srt-live-server from https://github.com/OpenIRL/srt-live-server

## Get started

You can run the Container with the following command:

```shell
docker run -d --restart unless-stopped --name srtla-receiver -p 5000:5000/udp -p 4001:4001/udp -p 8080:8080 ghcr.io/openirl/srtla-receiver:1.0.0
```