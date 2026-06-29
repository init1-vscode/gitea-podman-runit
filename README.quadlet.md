# Gitea Quadlet Container Deployment

This documentation describes how to deploy Gitea using Podman's quadlet feature, introduced in Podman 5.8+. Quadlets provide a simplified way to manage container deployments using `.container` files.

## Overview

Gitea can now be deployed as a systemd service using quadlet's `.container` files, which are a more user-friendly approach than traditional Docker Compose or podman run commands. This method leverages Podman's built-in service management capabilities through systemd.

## Key Changes from Traditional Deployment

### Service Management Transition

The most significant change in the podman deployment is the replacement of s6 with runit as the service manager:

- **Old (Docker setup)**: Used s6 service manager with `/etc/s6/` directory structure
- **New (Podman setup)**: Uses runit service manager with `/run/service/` directory structure

This change provides:
1. Better integration with Podman's native service management
2. Smaller footprint and simpler configuration
3. Improved compatibility with systemd-based deployments

## Requirements

- Podman 5.8 or newer
- Systemd (Linux distributions with systemd)
- Container storage configured for Podman

## Deployment Structure

The podman deployment structure is organized as follows:

```
/etc/containers/systemd/
├── gitea.container
└── gitea.env

/data/
└── gitea/ (persistent data directory)

/run/service/
├── gitea/ (runit service)
└── openssh/ (runit service)
```

## Quadlet File Structure

### gitea.container file:
```ini
[Unit]
Description=Gitea Container
After=network.target

[Container]
Image=gitea/gitea:latest
ContainerName=gitea
PublishPort=3000:3000
PublishPort=2222:22
Volume=/var/lib/gitea:/data
Environment=USER_UID=1000
Environment=USER_GID=1000
Environment=GITEA_CUSTOM=/data/gitea

[Service]
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### gitea.env file:
```bash
# Environment variables for Gitea quadlet deployment
USER_UID=1000
USER_GID=1000
GITEA_CUSTOM=/data/gitea
```

## Deployment Steps

### 1. Create Quadlet Configuration Files

Create the quadlet files in `/etc/containers/systemd/`:

```bash
sudo mkdir -p /etc/containers/systemd
sudo touch /etc/containers/systemd/gitea.container
sudo touch /etc/containers/systemd/gitea.env
```

### 2. Configure gitea.container

Edit `/etc/containers/systemd/gitea.container` with the configuration shown above.

### 3. Configure gitea.env

Edit `/etc/containers/systemd/gitea.env` with the environment variables shown above.

### 4. Enable and Start Services

```bash
sudo systemctl daemon-reload
sudo systemctl enable gitea.container
sudo systemctl start gitea.container
```

## Directory Structure

The quadlet deployment uses specific directory structures:

- `/etc/containers/systemd/` - Quadlet configuration files
- `/var/lib/gitea/` - Data persistence directory (must be writable)
- `/data/` - Container data mount point
- `/run/service/` - Runit service management directory

## Environment Variables

The following environment variables are required for proper quadlet operation:

- `USER_UID`: User ID for the git user inside the container
- `USER_GID`: Group ID for the git user inside the container
- `GITEA_CUSTOM`: Path to custom configuration directory inside the container

## Port Mappings

- Port 3000: Gitea web interface
- Port 2222: SSH access (mapped from container port 22)

## Volume Mounts

- `/var/lib/gitea:/data` - Required for persistent data storage

## Service Management with Runit

The podman deployment uses runit instead of s6:

- Services are managed via `/run/service/` directory
- Each service has a `run` script in its subdirectory
- Service management is handled automatically by Podman's container runtime

### Gitea Service (`/run/service/gitea/run`):
```bash
#!/bin/sh
exec chpst -u git:git /usr/local/bin/gitea web
```

### SSH Service (`/run/service/openssh/run`):
```bash
#!/bin/sh
exec /usr/sbin/sshd -D -e
```

## Quadlet Advantages

1. **Simplified Management**: Single file configuration instead of complex docker-compose.yml
2. **Integration with systemd**: Automatic service management and restart policies
3. **Easier Updates**: Standard systemctl commands for managing services
4. **User-Friendly**: More intuitive than traditional podman run commands
5. **Built-in Health Checks**: Automatic restarts on failure
6. **Runit Integration**: Lightweight and reliable service management

## Troubleshooting

### Common Issues

1. **Service fails to start**:
   - Check `journalctl -u gitea.container` for error details
   - Verify required directories exist and have correct permissions

2. **Port conflicts**:
   - Ensure ports 3000 and 2222 are not already in use on the host

3. **Permission errors**:
   - Verify that the user specified in `USER_UID`/`USER_GID` exists and has appropriate permissions

### Debugging Commands

```bash
# Check quadlet service status
systemctl status gitea.container

# View logs
journalctl -u gitea.container -f

# Inspect container
podman inspect gitea

# List running containers
podman ps

# Check runit services
ls /run/service/
```

## Migration from Previous Deployments

If you previously deployed Gitea using other methods:
1. Stop the old deployment
2. Backup your data from `/var/lib/gitea`
3. Create quadlet configuration files as described above
4. Start the new quadlet service
5. Verify functionality and remove old deployment method

## Security Considerations

- Ensure proper firewall rules for exposed ports (3000, 2222)
- Regularly update the Gitea container image
- Monitor logs for unusual activity
- Use strong passwords and SSH keys

## Documentation References

For more information about Podman quadlets:
- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.1.html)
- [Podman Container Configuration](https://docs.podman.io/en/latest/markdown/podman-run.1.html)