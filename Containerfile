FROM quay.io/fedora/fedora-coreos@sha256:9ccaf584660e7acf63f7f6658c13a3adf97e88f6e192b241a3b4abd364a55a2b

COPY rootfs/ /

# Replace VERSION in /etc/yum.repos.d/kubernetes.repo with the latest major and minor version of Kubernetes
RUN curl -s https://api.github.com/repos/kubernetes/kubernetes/releases/latest \
    | jq -r '.tag_name' \
    | sed -E 's/^(v[0-9]+\.[0-9]+)\..*/\1/' \
    | xargs -I{} sed -i 's/VERSION/{}/g' /etc/yum.repos.d/kubernetes.repo


# Install packages for Kubernetes
RUN dnf install -y containernetworking-plugins kubeadm kubelet

# Enable services for Kubernetes
RUN systemctl enable \
        containerd \
        kubelet.service

# Disable Docker
RUN systemctl disable docker.socket

# Create containerd config files
RUN containerd config default > /etc/containerd/config.toml
RUN sed -i 's/imports = .*/imports = ["\/etc\/containerd\/config.d\/*.toml"]/' /etc/containerd/config.toml

# Prep directories for Kubernetes
#RUN for path in /var/lib/etcd /etc/kubernetes/pki /etc/kubernetes/pki/etcd /etc/cni/net.d; \
#    do \
#      mkdir -vp $path && chcon -vt svirt_sandbox_file_t $path; \
#    done

# Disable SELinux
# SELinux causes some issues
# I haven't tested it in a few versions, so this may be able to be enabled again
sed -i 's/SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

# Enable bootupd-auto service
# This service will automatically run `bootupctl update`
# on start to keep all components updates
RUN systemctl enable bootupd-auto.service
