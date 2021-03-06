#@jorgeklz

clustering.by.distance<-function(distance.matrix){
  #Applies mstknn
  library("mstknnclust")
  results <- mst.knn(distance.matrix)
  return (results)
}


setwd("JCC2018")
#Load data
dataset.earthquake<-read.table("sismos.csv", header = TRUE, sep=",", stringsAsFactors = FALSE)
#################
#Preprocessing
#################
#Delete grade symbol.
dataset.earthquake$Lat<-sub('[^A-Za-z0-9.]','',dataset.earthquake$Lat)
dataset.earthquake$Long<-sub('[^A-Za-z0-9.]','',dataset.earthquake$Long)
#Delete faltante depth '-'
dataset.earthquake=dataset.earthquake[dataset.earthquake$Depth!="-",]
#Delete 'Ecuador - '. Filter only Province
dataset.earthquake$Region<-sub('\\Ecuador - ', '', dataset.earthquake$Region)
#Delete 'Colombia'
dataset.earthquake=dataset.earthquake[dataset.earthquake$Region!="Colombia",]
#Delete 'Northern Peru'
dataset.earthquake=dataset.earthquake[dataset.earthquake$Region!="Northern Peru",]
#Delete 'Off Coast of Northern Peru'
dataset.earthquake=dataset.earthquake[dataset.earthquake$Region!="Off Coast of Northern Peru",]
#Delete 'Near Coast of Northern Peru'
dataset.earthquake=dataset.earthquake[dataset.earthquake$Region!="Near Coast of Northern Peru",]
#Delete 'km' in closerCity
dataset.earthquake$CloserCity<-gsub('km', '', dataset.earthquake$CloserCity, fixed=TRUE)
#Delete 'number in km 
dataset.earthquake$CloserCity<-gsub('[[:digit:]]', '', dataset.earthquake$CloserCity, fixed=FALSE)
#Delete 'a . de'
dataset.earthquake$CloserCity<-gsub('a . de ', '', dataset.earthquake$CloserCity, fixed=TRUE)
#Delete '.'
dataset.earthquake$CloserCity<-gsub('.', '', dataset.earthquake$CloserCity, fixed=TRUE)
#Delete ', Province'
#Change Galapagos Islands, Ecuador by Galapagos
dataset.earthquake[dataset.earthquake$Region=="Galapagos Islands, Ecuador",]$Region="Galapagos"
#Change Peru-Ecuador Border Region by Peru-Ecuador Border
dataset.earthquake[dataset.earthquake$Region=="Peru-Ecuador Border Region",]$Region="Peru-Ecuador Border"

#Delete 'Country-Border'
dataset.earthquake=dataset.earthquake[dataset.earthquake$Region!="Colombia-Ecuador Border",]
dataset.earthquake=dataset.earthquake[dataset.earthquake$Region!="Peru-Ecuador Border Region",]
dataset.earthquake=dataset.earthquake[dataset.earthquake$Region!="Peru-Ecuador Border",]

#Delete 'Galapagos'
dataset.earthquake=dataset.earthquake[dataset.earthquake$Region!="Galapagos",]

#Delete 'Coast'
dataset.earthquake=dataset.earthquake[dataset.earthquake$Region!="Off Coast of Ecuador",]
#dataset.earthquake=dataset.earthquake[dataset.earthquake$Region!="Near Coast of Ecuador",]

#Separate grade of N,S and W E
library("dplyr")
library("tidyr")
#Separate column Lat in two new column: Latitude Pole. White space is the separator character.
dataset.earthquake=dataset.earthquake%>% separate(Lat, c("Latitude", "PoleLat"), " ",extra = "drop")
dataset.earthquake=dataset.earthquake%>% separate(Long, c("Longitude", "PoleLon"), " ",extra = "drop")
#Convert Latitude and Longitude to GD (grados decimales). It is the same value when is N or E. But it is negative in else.
#If is S then -1
dataset.earthquake[dataset.earthquake$PoleLat=="S","Latitude"]=-1*as.numeric(dataset.earthquake[dataset.earthquake$PoleLat=="S","Latitude"])
dataset.earthquake$Latitude=as.numeric(dataset.earthquake$Latitude)
#If is W then -1
dataset.earthquake[dataset.earthquake$PoleLon=="W","Longitude"]=-1*as.numeric(dataset.earthquake[dataset.earthquake$PoleLon=="W","Longitude"])
dataset.earthquake$Longitude=as.numeric(dataset.earthquake$Longitude)
 

#Data only affected Provinces (Esmeraldas, Manabi y Sta Elena and Ocean Pacific Coast
dataset.earthquake=subset(dataset.earthquake, dataset.earthquake$Region=="Near Coast of Ecuador" | dataset.earthquake$Region=="Esmeraldas" | dataset.earthquake$Region=="Manabi")
dataset.earthquake=subset(dataset.earthquake, dataset.earthquake$Latitude>=-2)


#################
#Features selection
#################
minimo=1  #min magnitude
maximo=9  #max magnitude
dataset.earthquake<-subset(dataset.earthquake, Mag>=minimo & Mag<maximo)
#Feature selection: Magnitude and Depth
dataset.features<-dataset.earthquake[,c("Mag","Depth", "Latitude", "Longitude", "CloserCity", "Region")]
dataset.features$Depth=as.numeric(dataset.features$Depth)
dataset.features$Region=as.factor(dataset.features$Region)
dataset.features$CloserCity=as.factor(dataset.features$CloserCity)
#Cleaning. Only positive numbers
dataset.features<-subset(dataset.features, Mag>0)
dataset.features<-subset(dataset.features, Depth>0)

#################
#Statitical Analysis
#################
#Generate statistical graphics
library(dplyr)
library(ggplot2)

summary_sismos<- dataset.features %>%  group_by(CloserCity) %>%  summarise(lower = min(Mag), upper = max(Mag), Mag = median(Mag))
setEPS()
  postscript("paper/boxplot.eps", width = 16, height =6)
  ggplot(dataset.features, aes(factor(Region), Mag))+
    stat_boxplot(geom ='errorbar') + geom_boxplot() + theme_classic() +
    theme(axis.text.x = element_text(angle = 90, hjust = 1), 
          legend.position="none", plot.title = element_text(hjust = 0.5), 
          axis.title.x = element_blank()) + ylab("Magnitude (Mw)") +
    geom_boxplot(outlier.colour = NULL)
dev.off()

#############################
#Earthquake distribution
############################
library(dplyr)
library(ggmap)
library(wesanderson)

#########ECUADOR
epicentro <- data.frame(Mag=c(7.8), Depth=c(27), Latitude = c(0.37), Longitude = c(-79.94), 
                        CloserCity="Muisne", Region="Earthquake Epicenter", stringsAsFactors = FALSE) 
dataset.features=rbind(dataset.features, epicentro)
dataset.features$categoryMag = cut(dataset.features$Mag,c(1.0, 3.0, 3.9, 4.9, 5.9, 6.9, 8), labels = c("1.0 - 3.0", "3.0 - 3.9", "4.0 - 4.9", "5.0 - 5.9", "6.0 - 6.9", "Epicenter"))
dataset.features$categoryDepth = cut(dataset.features$Depth,c(0, 60, 300, 1000), labels = c("< 60", "60 - 300", ">300"))

archivo=paste0("aftershocks_ecuador.eps")

if(!file.exists(archivo)){
      setEPS()
      postscript(archivo, width = 14, height =14)
      map = get_map(location='Riobamba', zoom=7, maptype="roadmap")
      ggmap(map, legend = "bottomright", extent = "device") + 
        geom_point(aes(x = Longitude, y = Latitude, fill = Mag, size = Depth), shape = 21, 
                   data = dataset.features) + 
        scale_fill_gradient(high = "red", low = "yellow") +  
        scale_size_continuous(range = c(1, 10)) 
      dev.off()
}



#Filter features
dataset.features=dataset.features[-nrow(dataset.features),]

#################
#Distance Matrix
#################
#Calculates distance matrix latitude longitude (spatial localtion) (harvensin)
library("geosphere")
matriz=dataset.features[, c("Longitude", "Latitude")]
distance.matrix.haversine.lon.lat <-base::as.matrix(distm(matriz, fun=distHaversine))
rownames(distance.matrix.haversine.lon.lat)<-rownames(dataset.features)
colnames(distance.matrix.haversine.lon.lat)<-rownames(distance.matrix.haversine.lon.lat)
resultados5<-clustering.by.distance(distance.matrix.haversine.lon.lat)

#################
#RUN MST-kNN
#################

particionado=resultados5$partition
#Reemplazo el número de fila con la correspondiente region, ciudad...
columnas= dataset.features[particionado[,"object"],
                           c("Mag","Depth","Latitude","Longitude", "CloserCity", "Region", "categoryMag", "categoryDepth")]
tabla=cbind(columnas, cluster=particionado$cluster)
datos_distancia=as.vector(distance.matrix.haversine.lon.lat)
datos_distancia=datos_distancia[datos_distancia>0]

 

library("igraph")
#Analysis only eartquakes in continental Ecuador
tabla=subset(tabla, tabla$Region %in% "Manabi" | tabla$Region %in% "Esmeraldas" )
tabla=subset(tabla, !(tabla$CloserCity %in% "nas"))

#Analysis each cluster
for (i in 1:max(tabla$cluster)){
    actual=subset(tabla, tabla$cluster==i)
    todos=subset(distance.matrix.haversine.lon.lat, rownames(distance.matrix.haversine.lon.lat) %in% rownames(actual))
    todos=as.data.frame(todos[,rownames(actual)])
    #Distance matrix to nodes pairs with weight
    pares=data.frame( t(combn(names(todos),2)), weight=t(todos)[lower.tri(todos)] )
    pares$weight=round(log(pares$weight),2)
    pares$weight[pares$weight<=0]=0
    #Create graphs of each cluster
    net=graph.data.frame(pares, directed=FALSE, vertices=NULL)
    #Calcula centralidades
    medida=igraph::closeness(net, mode="all")
    cat ("closeness ",  which.max(medida), "   \n")
    print(medida[which.max(medida)])

}

#Save Results
write.table(tabla, file="clustering.results.table.csv", sep=",")
write.table(distance.matrix.haversine.lon.lat, file="clustering.results.distances.csv", sep=",")

