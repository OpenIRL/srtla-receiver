# SRTla Receiver

SRTla receiver with support for multiple streams and statistics integration.

## Project Information

This project is based on the following components:
- SRT: [onsmith/srt](https://github.com/onsmith/srt)
- SRTla: [OpenIRL/srtla](https://github.com/OpenIRL/srtla)
- SRT-Live-Server: [OpenIRL/srt-live-server](https://github.com/OpenIRL/srt-live-server)

### Project Support

If you'd like to support this project, please visit my GoFundMe page: [gofundme](https://gofund.me/07644414)

Your support helps enable further development and improvements.

## Getting Started

### Running the Container

You can run the container with the following command:

```shell
docker run -d --restart unless-stopped --name srtla-receiver \
  -p 5000:5000/udp \
  -p 4001:4001/udp \
  -p 8080:8080 \
  ghcr.io/openirl/srtla-receiver:latest
```

To use the started container you can use the following scheme:

### Sending a Stream
#### SRTla

| Type | URL |
|------|-----|
| Schema | `srtla://<your-ip>:5000?streamid=publish/stream/<feed-id>` |
| Example | `srtla://127.0.0.1:5000?streamid=publish/stream/feed` |

#### SRT

| Type | URL |
|------|-----|
| Schema | `srt://<your-ip>:4001?streamid=publish/stream/<feed-id>` |
| Example | `srt://127.0.0.1:4001?streamid=publish/stream/feed` |

### Receiving a Stream

#### SRT

| Type | URL |
|------|-----|
| Schema | `srt://<your-ip>:4001?streamid=play/stream/<feed-id>` |
| Example | `srt://127.0.0.1:4001?streamid=play/stream/feed` |

## Statistics Integration

The SRTla Receiver provides a statistics interface that can be used for integration with tools like NOALBS (Node OBS Automatic Live Switching).

### Statistics Endpoint

| Type | URL |
|------|-----|
| Schema | `http://<your-ip>:8080/stats/publish/stream/<feed-id>` |
| Example | `http://127.0.0.1:8080/stats/publish/stream/feed` |

### NOALBS Integration

To use the SRTla Receiver with NOALBS, you can specify the statistics endpoint in your NOALBS configuration. This allows for automatic scene switching based on stream metrics.
Example NOALBS configuration:

```json
{
  # rest of the config ...
  "switcher": {
    # rest of the config ...
    "streamServers": [
      {
        "streamServer": {
          "type": "SrtLiveServer",
          "statsUrl": "http://127.0.0.1:8080/stats/publish/stream/feed",
          "publisher": "publish/stream/feed"
        },
        "name": "Stream",
        "priority": 0,
        "enabled": true
      }
    ]
    # rest of the config ...
  }
  # rest of the config ...
}
```

## Troubleshooting

If you encounter issues with the SRTla Receiver, ensure that:
- All required ports (5000/udp, 4001/udp, 8080/tcp) are accessible
- Stream IDs are correctly formatted
- Your firewall settings allow UDP traffic on the configured ports

## Contributing

Contributions to the project are welcome! Please open an issue or pull request on GitHub.
