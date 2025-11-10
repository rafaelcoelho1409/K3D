from urllib.request import urlretrieve
from diagrams import Diagram, Cluster, Edge
from diagrams.custom import Custom
from diagrams.onprem.iac import Terraform
from diagrams.onprem.container import Docker
from diagrams.k8s.ecosystem import Helm
from diagrams.onprem.gitops import ArgoCD
from diagrams.onprem.vcs import Gitlab

# Custom logos
for url, icon in [
    (
        "https://k3d.io/stable/static/img/k3d_logo_black_blue.svg",
        "k3d.svg"
    ),  # K3D
    (
        "https://rancher.com/docs/img/logo-square.png",
        "rancher.png"
    ),  # Rancher
    (
        "https://avatars.githubusercontent.com/u/28732122?s=280&v=4",
        "localstack.png"
    )  # LocalStack
]:
    urlretrieve(url, icon)

with Diagram(
    "DevOps Tools on K3D Cluster with Terraform",
    show = False,
    filename = "terraform_k3d_diagram",
    outformat = "png",
    #direction = "TB",
    direction = "LR",
    graph_attr = {
        "fontsize": "16",
        "bgcolor": "white",
        "pad": "0.8",
        "splines": "spline",
        "nodesep": "1.0",
        "ranksep": "1.5"
    }):

    terraform = Terraform("Terraform\nRoot Module")

    with Cluster(
        "Infrastructure Layer",
        graph_attr = {
            "bgcolor": "#E8F4F8",
            "pencolor": "#0066CC",
            "penwidth": "2",
            "style": "rounded"
        }):
        docker = Docker("Docker Engine")
        k3d = Custom("K3D Cluster\n(1 server + 3 agents)", "k3d.svg")
        k3d_registry = Custom("K3D Registry\n(port 5000)", "k3d.svg")
        docker >> k3d >> k3d_registry

    helm = Helm("Helm\nPackage Manager")

    with Cluster(
        "K8s Services",
        graph_attr = {
            "bgcolor": "#FAFAFA",
            "pencolor": "#666666",
            "penwidth": "2",
            "style": "rounded"
        }):
        with Cluster(
            "GitOps & CI/CD",
            graph_attr = {
                "bgcolor": "#FFF4E6",
                "pencolor": "#FF6B35",
                "style": "rounded"
            }):
            argocd = ArgoCD("ArgoCD\n:9080")
            argocd_image_updater = ArgoCD("Image Updater")
            gitlab = Gitlab("GitLab\n:8090/:2222")
            argocd >> argocd_image_updater

        with Cluster(
            "Management",
            graph_attr = {
                "bgcolor": "#F0F8F0",
                "pencolor": "#28A745",
                "style": "rounded"
            }):
            rancher = Custom("Rancher\n:7080/:7443", "rancher.png")
            localstack = Custom("LocalStack\n:4566", "localstack.png")

    # Main flow
    terraform >> Edge(color = "#5C4EE5", style = "bold") >> docker
    terraform >> Edge(color = "#5C4EE5", style = "bold") >> helm
    k3d >> Edge(color = "#0066CC", style = "dashed") >> helm
    helm >> Edge(color = "#004D99", style = "bold") >> [argocd, gitlab, rancher, localstack]