

#Wir verwenden dafür den offiziellen Terraform-cloud-Block. Damit weiß Terraform, in welchem HCP-Workspace 
#der State künftig gespeichert wird und wo Remote-Runs ausgeführt werden. 
#HashiCorp Developer


#Erstelle in VS Code folgende Datei:

#learning-terraform-on-sapbtp/BTP/cloud.tf

#Füge diesen Inhalt ein:


terraform {
  cloud {
    organization = "sap-ai-landing-zone"

    workspaces {
      name = "sap-btp-core"
    }
  }
}
