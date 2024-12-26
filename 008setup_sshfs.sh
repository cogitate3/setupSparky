
# 设置将ssh远程的一个目录挂载到本地：https://github.com/libfuse/sshfs
sudo apt install -y sshfs
# sshfs user@host:/path/to/folder /path/to/mountpoint


# Mount a WebDAV resource as a regular file system： https://savannah.nongnu.org/projects/davfs2
sudo apt install -y davfs2
# davfs2 的主要命令是 mount.davfs，而不是直接的 davfs2。你可以尝试使用以下命令来挂载 WebDAV 资源：
sudo mount -t davfs https://your-webdav-url /your/mount/point

