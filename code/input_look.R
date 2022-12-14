library(fields)
library(lubridate)
library(ncdf4)


setwd('~/Documents/nasa/data/lowres_4km')
parms <- c('CHL_chlor_a','FLH_nflh','RRS_Rrs_443','RRS_Rrs_488','RRS_Rrs_531','RRS_Rrs_547','RRS_Rrs_555','RRS_Rrs_667','RRS_Rrs_678')

yr <- 2003
data <- readRDS(paste0('aqua_modis_daily_',yr,'_4km.rds'))
modis <- nc_open(paste0('modisa_daily_',yr,'.nc'))
for(i in 1:9){
  data2 <- ncvar_get(modis,paste(substr(parms[i],5,20)))
  scale_factor <- ncatt_get(modis,paste(substr(parms[i],5,20)),'scale_factor')$value
  add_offset <- ncatt_get(modis,paste(substr(parms[i],5,20)),'add_offset')$value
  imagePlot(apply(data[i,,,],c(1,2),mean,na.rm=T))
  imagePlot((apply(data2,c(1,2),mean,na.rm=T)-add_offset)/scale_factor)
  image(apply(data[i,,,],c(1,2),mean,na.rm=T)-((apply(data2,c(1,2),mean,na.rm=T)-add_offset)/scale_factor))
  print(identical(data[i,,,],data2))
  test <- (data2-add_offset)/scale_factor
  print(identical(data[i,,,],test))
}

# data2 <- readRDS(paste0('modisa_daily_',yr,'.rds'))
# identical(data,data2) # should not be idenitcal due to reprocessing
for(i in 1:9){
  dates <- seq(as.Date(paste0(yr,'-01-01')),as.Date(paste0(yr,'-12-31')),by='day')
  tmp <- log10(apply(data[i,,,],c(1,2),mean,na.rm=T))
  tmp2 <- log10(apply(data[i,,,],c(1,2),sd,na.rm=T))
  if(length(which(tmp2==-Inf))>0){
    tmp2[tmp2==-Inf] <- NA
  }
  tm <- aggregate(apply(data[i,,,],3,mean,na.rm=T),by=list(month(dates)),mean,na.rm=T)
  tsd <- aggregate(apply(data[i,,,],3,sd,na.rm=T),by=list(month(dates)),sd,na.rm=T)
  # tmp <- apply(data[i,,,],c(1,2),quantile,.9,na.rm=T)
  # tmp <- apply(data[i,,,],c(1,2),function(x) ifelse(all(is.na(x)),1,0))
  par(mfrow=c(2,2))
  imagePlot(tmp[,ncol(tmp):1],asp=1,col=mako(60),nlevel=59)
  mtext(parms[i])
  imagePlot(tmp2[,ncol(tmp2):1],asp=1,col=plasma(60),nlevel=59)
  barplot(tm$x,names.arg = month.abb[1:12],las=2,log='y')
  barplot(tsd$x,names.arg = month.abb[1:12],las=2,log='y')
}
tmp3 <- apply(data[i,,,],c(1,2),function(x) length(which(!is.na(x))))
x <- aggregate(apply(data[i,,,],3,function(x) length(which(!is.na(x)))),by=list(month(dates)),sum)
par(mfrow=c(1,2))
imagePlot(tmp3[,ncol(tmp3):1],asp=1,col=rocket(60),nlevel=59)
barplot(x$x,names.arg = month.abb[1:12],las=2)


### sst

sst_brks <- seq(22,29,.2)
cols <- plasma(length(sst_brks)-1)

par(mfrow=c(2,2))
for(i in 2003:2021){
  data <- readRDS(paste0('mursst_daily_',i,'.rds'))
  
  tmp <- apply(data[,,],c(1,2),mean,na.rm=T)
  tmp2 <- apply(data[,,],c(1,2),sd,na.rm=T)
  imagePlot(tmp,asp=1,col=cols,breaks=sst_brks)
  contour(tmp,levels=seq(22,29,1),add=T)
  mtext(i)
  imagePlot(tmp2,asp=1,col=mako(60),nlevel=59)
}
