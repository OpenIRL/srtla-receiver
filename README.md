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

### Install the Receiver

The Receiver provides a shell script for easy installation on Ubuntu and Debian. Complete the following steps to install
using the shell script:

1. Download the runtime management script (`receiver.sh`) to your machine:
   ```shell
   curl -Lso receiver.sh "https://raw.githubusercontent.com/OpenIRL/srtla-receiver/refs/heads/main/receiver.sh" && chmod 700 receiver.sh
   ```
2. Run the installer script. It will create `./data` directory and `./.apikey` file they will be created realtive to the
   location of the `receiver.sh`
   ```shell
   ./receiver.sh install
   ```
3. Complete the prompts in the installer (most time just pressing enter)

### Create First Publisher

To use the started container, open the management URL (e.g., `http://127.0.0.1:3000`) shown in the console in your browser.

#### Configuration Steps

1. Click on "Configure Settings" on the welcome screen
2. In the modal that opens, you'll find 2 input fields and one switch. Enter the API key shown in the console
   - If you don't have the API key anymore, navigate to the directory where srtla-receiver is installed and run `cat .apikey`
3. Click "Save" after entering the API key
4. On the next screen, a new "Add Stream" button will appear. Click it and optionally fill in a description
5. After adding the publisher, click the arrow icon. In the Player section, you'll find a link icon
6. Click the link icon to get the stream URLs including the stats URLs as shown in the examples below

#### Sending a Stream

##### SRTla

| Type    | URL                                                                     |
|---------|-------------------------------------------------------------------------|
| Schema  | `srtla://<your-ip>:5000?streamid=<publish-key>`                         |
| Example | `srtla://127.0.0.1:5000?streamid=live_7388b95f0a6c4f69954f4519f204a554` |

##### SRT

| Type    | URL                                                                   |
|---------|-----------------------------------------------------------------------|
| Schema  | `srt://<your-ip>:4001?streamid=<publish-key>`                         |
| Example | `srt://127.0.0.1:4001?streamid=live_7388b95f0a6c4f69954f4519f204a554` |

#### Receiving a Stream

##### SRT

| Type    | URL                                                                   |
|---------|-----------------------------------------------------------------------|
| Schema  | `srt://<your-ip>:4001?streamid=<play-key>`                            |
| Example | `srt://127.0.0.1:4001?streamid=play_60a0055a7fdb436d92fab3a943f5c55c` |

## Statistics Integration

The SRTla Receiver provides a statistics interface that can be used for integration with tools like NOALBS (Node OBS Automatic Live Switching).

### Statistics Endpoint

| Type    | URL                                                                 |
|---------|---------------------------------------------------------------------|
| Schema  | `http://<your-ip>:8080/stats/<play-id>`                             |
| Example | `http://127.0.0.1:8080/stats/play_60a0055a7fdb436d92fab3a943f5c55c` |

### Statistics Endpoint (Legacy)

| Type             | URL                                                                          |
|------------------|------------------------------------------------------------------------------|
| Schema (Legacy)  | `http://<your-ip>:8080/stats/<play-id>?legacy=1`                             |
| Example (Legacy) | `http://127.0.0.1:8080/stats/play_60a0055a7fdb436d92fab3a943f5c55c?legacy=1` |

### NOALBS Integration

To use the SRTla Receiver with NOALBS, you can specify the statistics endpoint in your NOALBS configuration. This allows
for automatic scene switching based on stream metrics.
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
                     "statsUrl": "http://127.0.0.1:8080/stats/play_60a0055a7fdb436d92fab3a943f5c55c?legacy=1",
                     "publisher": "live"
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

- All required ports (5000/udp, 4000/udp, 4001/udp, 8080/tcp) are accessible
- Stream IDs are correctly formatted
- Your firewall settings allow UDP traffic on the configured ports

## Contributing

Contributions to the project are welcome! Please open an issue or pull request on GitHub.
