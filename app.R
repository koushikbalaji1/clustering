
if(!require(shiny)) install.packages("shiny")
if(!require(cluster)) install.packages("cluster")
if(!require(factoextra)) install.packages("factoextra")
if(!require(DMwR)) install.packages("DMwR")
if(!require(dplyr)) install.packages("dplyr")
if(!require(data.table)) install.packages("data.table")
if(!require(DT)) install.packages("DT")
if(!require(formattable)) install.packages("formattable")
if(!require(shinythemes)) install.packages("shinythemes")
if(!require(shinycssloaders)) install.packages("shinycssloaders")
if(!require(stringr)) install.packages("stringr")

options(spinner.color.background="#F5F5F5")

ui <- fluidPage(theme = shinytheme("sandstone"),
                navbarPage(title = "Clustering",id =  "Clustering",
                           tabPanel("Overview",tags$h4("ABOUT"),tags$h5("clustering is employed in building relevant segments which are homogenous in certain behavioural aspects and can be targeted using the similar strategy"),br(),
                                    tags$hr(),
                                    div(column(width = 3, 
                                               div(fileInput("input_file_selector", "Choose data File",
                                                             accept = c(
                                                               "text/csv",
                                                               "text/comma-separated-values,text/plain",
                                                               ".csv")),
                                                   checkboxInput("header", "Header", TRUE),
                                                   downloadButton('template_data','Download template')),style = "border-right: 1px solid silver;"))
                           ),
                           tabPanel("Data exploration",column(width = 10,dataTableOutput("contents"), style = "font-size:80%;border-right: 1px solid silver;"),
                                    column(width = 2,
                                           selectizeInput(inputId = "Measures_selector",choices = c(""),multiple = TRUE,label = "Choose Measures"),
                                           selectizeInput(inputId = "Cluster_selector",choices = c(2:7),selected = 4,label = "Choose Cluster size"),
                                           div(actionButton("apply_button","Run clustering"),style = "float:right"),br(),br(),tags$hr(),
                                           div(actionButton("cluster_button","Check cluster size",icon = icon("paper-plane"),width = "190px"),style = "float:right")
                                    )
                           ),
                           tabPanel("Cluster exploration",
                                    tags$b(verbatimTextOutput("captions_clusexpl")),
                                    tags$hr(),
                                    column(width = 6,tags$h3("Cluster Plot"),
                                           withSpinner(plotOutput("cluster_plot"),type = getOption("spinner.type",default = 3 ),color.background = getOption("spinner.color.background")),
                                           style = "border-right: 1px solid silver;"
                                    ),
                                    column(width = 6,tags$h3("Silhouette Plot"),
                                           withSpinner(plotOutput("cluster_plot_sil"),type = getOption("spinner.type",default = 3),color.background = getOption("spinner.color.background"))
                                    ),tags$h3("Cluster details"),
                                    div(withSpinner(dataTableOutput("clus_details"),type = getOption("spinner.type",default = 3),color.background = getOption("spinner.color.background")),style = "font-size:80%")
                           ),
                           tabPanel("Results",
                                    div(column(width =10,tags$b(verbatimTextOutput("captions_store")),
                                               tags$hr()
                                    ),
                                    column(width = 2,
                                           selectizeInput(inputId = "Cluster_selector_drop",choices = c('All'),label = "Choose Cluster")
                                    )
                                    ),
                                    div(style = "font-size:80%",dataTableOutput("clus_labelled"))
                           ),
                           tabPanel("Migration",tags$h4("ABOUT"),tags$h5("Migration analysis illustrates the evolution of similar segments over a period of time to detect prominent migration patterns "),br(),
                                    actionButton("mig","Run Migration"),
                                    tags$hr(),
                                    column(width = 3,div(
                                               div(fileInput("last_year", "Choose Last year data file",
                                                             accept = c(
                                                               "text/csv",
                                                               "text/comma-separated-values,text/plain",
                                                               ".csv")),
                                                   checkboxInput("header_ly", "Header", TRUE)),tags$hr()),
                                               div(fileInput("ya", "Choose two year ago File",
                                                             accept = c(
                                                               "text/csv",
                                                               "text/comma-separated-values,text/plain",
                                                               ".csv")),
                                                   checkboxInput("header_ya", "Header", TRUE)),
                                        style = "border-right: 1px solid silver;"),
                                        column(width = 8,
                                               div(style = "font-size:80%",withSpinner(dataTableOutput("migrataion_results"),type = getOption("spinner.type",default = 3),color.background = getOption("spinner.color.background")))),
                                        column(width = 1,
                                               div(style = "font-size:80%",br(),br(),textOutput("legendary"),dataTableOutput("migration_legend")))
                                    
                           )
                )
)
migrate <- function(grid_data,This_year,Last_year,Year_ago){
  
  ly <- migration(grid_data,Last_year)
  tya <- migration(grid_data,Year_ago)
  migration_past <- left_join(tya,ly,by = "LY_1.Country")
  migration_recent <- left_join(migration_past,This_year[,c("Country","clabel")],by = c("LY_1.Country" = "Country"))
  colnames(migration_recent) <- c("Country","Previously","Last year","Current year")
  return(migration_recent)
}
migration <- function(grid_data,LY){
  
  grid_data_t <- data.frame(t(grid_data))
  closest.cluster <- function(x,grid_data_t) {
    cluster.dist <- apply(grid_data_t, 1, function(y) sqrt(sum((x-y)^2)))
    return(which.min(cluster.dist)[1])
  }
  row_name <- rownames(grid_data_t)
  col_name <- rownames(grid_data[c(1:(nrow(grid_data)-2)),])
  grid_data_t <- apply(grid_data_t,2,suppressWarnings(as.numeric))
  grid_data_t <- data.frame(grid_data_t)
  grid_data_t <- grid_data_t[-1,c(1:(ncol(grid_data_t)-2))]
  rownames(grid_data_t) <- c(row_name[-1])
  colnames(grid_data_t) <- c(col_name)
  
  filter_measures <- paste("Country",col_name,collapse =  "|",sep = "|")
  LY_1 <- LY[,c(grep(pattern = filter_measures,x=names(LY)))]
  LY_selected <- apply(LY_1[,c(-1)],2,as.numeric)
  ab <- apply(LY_selected,1,function(x) closest.cluster(x,grid_data_t))
  LY_1$closest <- ab
  temp <- data.frame(LY_1$Country,LY_1$closest)
  return(temp)
}
server <- function(input,output,session){
  
  # ----------------Input file size extended----------------#
  options(shiny.maxRequestSize = 30*1024^2)
  
  # ----------------Input file read----------------#
  input_data <- reactive({inFile <- input$input_file_selector
  
  if (is.null(inFile))
    return(NULL)
  
  temp <- read.csv(inFile$datapath,header = input$header,stringsAsFactors = FALSE)
  available_measures <- c(str_split_fixed(names(temp[,-1]),"_",2)[,1])
  updateSelectizeInput(session,inputId = "Measures_selector",choices = available_measures,selected = available_measures)
  return(read.csv(inFile$datapath,stringsAsFactors = FALSE,header = input$header))
  })
  
  #------------------Template for Data----------------#
  template <- data.frame("USA",	"937.3",	"25%")
  colnames(template) <- c("Country",	"Measure1",	"Measure2")
  output$template_data <- downloadHandler(filename = "Template.csv",content = function(file) { write.csv(template,file,row.names = FALSE)})
  
  #--------------------Display contents---------------------#
  observeEvent(input$input_file_selector,{
    updateTabsetPanel(session,inputId = "Clustering", selected = "Data exploration")
  })
  output$contents <- renderDataTable(input_data(),extensions = 'FixedColumns',options=list(lengthMenu = list(c(5,15,30,-1),c('5','15','30','All')),pageLength = 15,fixedColumns = list(leftColumns = 1),dom= 'lftrip',scrollX = TRUE,scrollY = "450px" ))
  
  cleaned_input <- reactive({
    
    temp <- input_data()
    
    temp[is.na(temp)] <- 0
    temp[temp=="-Inf"] <- 0
    temp[temp=="Inf"] <- 0
    temp[,c(-1)] <- round(temp[,c(-1)],digits = 2)
    
    return (temp)
  })
  
  #Creating data for clustering by scaling values 
  scaled_to_clustering <- reactiveValues(data = NULL)
  measures_selected <- reactiveValues(data = NULL)
  scaled_to_clustering_elbow_test <- reactiveValues(data = NULL)
  measures_selected_elbow_test <- reactiveValues(data = NULL)
  no_of_clusters <- reactiveValues(data = NULL )
  
  Clust_optimal <- function() {
    modalDialog(
      plotOutput("elbow_curve"),
      footer = tagList(actionButton("ok", "OK"))
    )
  }
  
  observeEvent(input$cluster_button,{
    measures_selected_elbow_test$data <- input$Measures_selector
    selected_measures <- paste0(measures_selected_elbow_test$data,collapse = "|")
    scaled_to_clustering_elbow_test$data <-scale(cleaned_input()[,(grepl(pattern = selected_measures,names(cleaned_input())))])
    showModal(Clust_optimal())
    output$elbow_curve <- renderPlot(fviz_nbclust(scaled_to_clustering_elbow_test$data,method = "silhouette",k.max = 7,FUNcluster = pam,verbose = T))
  })
  observeEvent(input$apply_button,{
    measures_selected$data <- input$Measures_selector
    selected_measures <- paste0(measures_selected$data,collapse = "|")
    scaled_to_clustering$data <-scale(cleaned_input()[,(grepl(pattern = selected_measures,names(cleaned_input())))])
    no_of_clusters$data <- input$Cluster_selector
    updateTabsetPanel(session,inputId = "Clustering", selected = "Cluster exploration")
    updateSelectizeInput(session,inputId = "Cluster_selector_drop",choices = c('All',1:input$Cluster_selector))
    
    output$cluster_plot <- renderPlot(fviz_cluster(pam_data(),xlab = "",ylab = "",main = ""))
    output$cluster_plot_sil <- renderPlot(fviz_silhouette(pam_data(),label = FALSE,print.summary = FALSE))
    output$clus_labelled <- renderDataTable({
      if(input$Cluster_selector_drop == "All")
      {grid_data()[]}
      else 
      {filter(grid_data(),clabel==as.numeric(input$Cluster_selector_drop))[,]}},selection = 'none',extensions = c("FixedColumns","Buttons"),options = list(lengthMenu = list(c(5,15,30,-1),c('5','15','30','All')),pageLength = 15,dom = "lftrBip", scrollX = TRUE,fixedColumns = list(leftColumns = 4), scrollY = "350px", buttons = c('copy','csv','pdf','excel')))
    output$clus_details <- renderDataTable(clust_out_t(),extensions = c("FixedColumns","Buttons"),selection = list(mode = 'single',target = 'none',selected = c(1)) ,options = list(ordering = FALSE,dom = "trB", scrollX = TRUE,pageLength = 15,fixedColumns = list(leftColumns = 1), buttons = c('copy','csv','pdf','excel')))
    
  })
  observeEvent(input$ok,{removeModal()})
  
  #Clustering
  pam_data <- reactive(pam(scaled_to_clustering$data,k = no_of_clusters$data))
  
  #Cluster details
  clust_out <- reactive(unscale(pam_data()$medoids,scaled_to_clustering$data))
  clust_out_values <- reactive({
    temp <- data.frame(t(clust_out()))
    temp$var <- row.names(temp)
    return(temp)
  })
  sil_details <- reactive({
    temp <- silhouette(pam_data())
    details <- data.frame(temp[1:dim(temp)[1],1:dim(temp)[2]])
    clus_details <- details %>% group_by(cluster) %>% summarise(width = mean(sil_width))
    return(clus_details)
  })
  clust_out_t <- reactive({
    temp <- data.frame(t(clust_out()))
    temp <- rbind(temp,t(pam_data()$clusinfo)[1,])
    row.names(temp)[nrow(temp)] <- "No of Countries"
    colnames(temp) <-paste0("Cluster ", 1:no_of_clusters$data)
    temp1 <- round(t(sil_details())[2,],digits = 3)
    temp1 <- rbind(temp,temp1)
    rownames(temp1)[length(rownames(temp1))] <- c("sil_width")
    return(temp1)
  })
  
  #-------------------Country details with labels---------------#
  grid_data <- reactive({
    temp <- cleaned_input()
    temp$clabel <- pam_data()$clustering
    temp <- temp %>% select("Country","clabel",everything())
    return(temp)
  })
  grid_data_display <- reactive({
    temp <- grid_data()
    
    if(c("Value|Average") %in% c(unlist(lapply(strsplit(names(temp[,-1:-3]), split = "_"), head, 1))))
    {
      temp1 <- apply(temp[grep("Value|Average",colnames(temp))],2,function(x)as.character(currency(x,"\u20B9")))
      temp2 <- temp[grep("Value|Average|clabel",colnames(temp),invert = TRUE)]
      temp3 <- temp[grep("clabel",colnames(temp))]
      temp4 <- cbind(temp3,temp2,temp1)
      return(temp4)
    }
    else
      
      return(temp)
  })
  
  #-----------------Captions for tabs-----------------#
  measures <- reactive(paste(input$Measures_selector, collapse = ","))
  output$captions_clusexpl <- renderText(paste0("Cluster Details - Measures selected : ",measures()))
  output$captions_store <- renderText(paste0("Cluster Details - Measures selected : ",measures()))
  
  
  last_year_data <- reactive({inFile <- input$last_year
  
  if (is.null(inFile))
    return(NULL)
  
  return(read.csv(inFile$datapath,stringsAsFactors = FALSE,header = input$header_ly))
  })
  year_ago_data <- reactive({inFile <- input$ya
  
  if (is.null(inFile))
    return(NULL)
  
  return(read.csv(inFile$datapath,stringsAsFactors = FALSE,header = input$header_ya))
  })
  
  observeEvent(input$mig,
               {
                 df <- migrate(clust_out_t(),grid_data(),last_year_data(),year_ago_data())
                 df[df==1]<-"Lone ranger"
                 df[df==2]<-"Marquee"
                 df[df==3]<-"Cash Cow"
                 df[df==4]<-"ROW"
                 df[df==5]<-"Euro stars"
                 df[df==6]<-"Euro emerging"
                 df[df==7]<-"Newbies"
                 
                 ramp <- colorRamp(c("darkolivegreen4","khaki1", "firebrick1"))
                 clrs <- rgb(ramp(seq(0, 1, length = 7)), max = 255)
                 
                 dff <- data.frame((c("Lone ranger","Marquee","Cash Cow","ROW","Euro stars","Euro emerging","Newbies")))
                 output$migration_legend <- renderDataTable(datatable(dff, rownames = FALSE,colnames = NULL, selection = 'none', options = list(dom = 't')) %>% 
                                                  formatStyle(names(dff),backgroundColor = styleEqual(c("Lone ranger","Marquee","Cash Cow","ROW","Euro stars","Euro emerging","Newbies"), c(clrs))))
                 output$legendary <- renderText("Legend")
                 output$migrataion_results <- renderDataTable({
                   datatable(df,selection = 'none',extensions = c("FixedColumns","Buttons"),options = list(lengthMenu = list(c(5,15,30,-1),c('5','15','30','All')),pageLength = 15,dom = "lftrBip", scrollX = TRUE,fixedColumns = list(leftColumns = 4), scrollY = "350px", buttons = c('copy','csv','pdf','excel'))) %>%
                     formatStyle(names(df[-1]),backgroundColor = styleEqual(c("Lone ranger","Marquee","Cash Cow","ROW","Euro stars","Euro emerging","Newbies"), c(clrs)))
                   })
                 }
               )
}


shinyApp(ui = ui, server = server)