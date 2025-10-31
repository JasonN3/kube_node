FROM quay.io/fedora/fedora-coreos@sha256:c39e73eff276872c698a53f54f91ba47621af9103b61a4b66f6c715003e598ff

COPY rootfs/ /

# Install general packages
RUN dnf install -y jq udisks2

# Replace VERSION in /etc/yum.repos.d/kubernetes.repo with the latest major and minor version of Kubernetes
RUN curl -s https://api.github.com/repos/kubernetes/kubernetes/releases/latest \
    | jq -r '.tag_name' \
    | sed -E 's/^(v[0-9]+\.[0-9]+)\..*/\1/' \
    | xargs -I{} sed -i 's/VERSION/{}/g' /etc/yum.repos.d/kubernetes.repo


# Install packages for Kubernetes
RUN dnf install -y containerd containernetworking-plugins kubeadm kubelet

# Enable services for Kubernetes
RUN systemctl enable \
        containerd \
        kubelet.service

# Disable Docker
RUN if systemctl is-enabled docker.socket 2>/dev/null; \
    then \
      systemctl disable docker.socket; \
    fi

# Create containerd config files
RUN containerd config default > /etc/containerd/config.toml && \
    mkdir -p /etc/containerd/config.d && \
    sed -i 's/imports = .*/imports = ["\/etc\/containerd\/config.d\/*.toml"]/' /etc/containerd/config.toml

# Prep directories for Kubernetes
#RUN for path in /var/lib/etcd /etc/kubernetes/pki /etc/kubernetes/pki/etcd /etc/cni/net.d; \
#    do \
#      mkdir -vp $path && chcon -vt svirt_sandbox_file_t $path; \
#    done

# Disable SELinux
# SELinux causes some issues
# I haven't tested it in a few versions, so this may be able to be enabled again
RUN sed -i 's/SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

# Enable bootupd-auto service
# This service will automatically run `bootupctl update`
# on start to keep all components updates
RUN systemctl enable bootupd-auto.service
