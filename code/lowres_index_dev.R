library(fields)
library(lubridate)
library(ncdf4)
library(ncdf4.helpers)
library(NISTunits)
library(rerddap)

### empty r erddap cache
# cache_delete_all(force = FALSE)

erddap_extract <- function(data, info, parameter){
  data_temp <- data$data
  ind_extract <- which(names(data_temp)==parameter)
  time_step <- unique(data_temp$time)
  lon <- data$summary$dim$longitude$vals
  lat <- data$summary$dim$latitude$vals
  
  new_data <- array(data_temp[,ind_extract], 
                    c(length(lon),
                      length(lat),
                      length(time_step)))
  
  row_ind <- which(info$alldata$NC_GLOBAL$attribute_name=='title')
  col_ind <- which(colnames(info$alldata$NC_GLOBAL)=='value')
  name <- info$alldata$NC_GLOBAL[row_ind,col_ind]
  name <- unlist(strsplit(name,split=','))
  return(list(data = new_data,
              lon = lon,
              lat = lat,
              time = time_step,
              name = name))
  # setClass('erddap',slots=c(data='matrix',lon='array',lat='array'))
  # return(new('erddap',data=new_data,lon=lon,lat=lat))
  # return(list(new_data,lon,lat))
}

vec_brk <- function(input) {
  core <- (diff(input)/2) + input[1:(length(input)-1)]
  beg <- input[1] - (diff(input[1:2])/2)
  last <- input[length(input)] + (diff(input[(length(input)-1):(length(input))])/2)
  output <- c(beg,core,last)
  output
}

### 1) download daily 4km Aqua data
# a) what bounding box
# (-87.5 30.7, -81, 24.2)
lonbox_w <- -87.5 ### mouth of Mississippi River
latbox_n <- 30.7 ### northern coast
lonbox_e <- -81 ### Florida Bay
latbox_s <- 24.2 ### southern edge of Key West

# b) which parameters
# chlor_a
# nflh
# rrs_443
# rrs_488
# rrs_531
# rrs_547
# rrs_555
# rrs_667
# rrs_678

# c) what derived parameters
# ABI - rrs_547 & nflh
# bbp_Morel - chlor_a
# bbp_Carder - rrs_555
# ssnlw488 - nlw_443, nlw_488, nlw_531
# RBD - nlw_667, nlw_678
# KBBI - nlw_667, nlw_678

## red band difference
### Ruhul Amin, Jing Zhou, Alex Gilerson, Barry Gross, Fred Moshary, and Samir Ahmed, "Novel optical techniques for detecting and classifying toxic dinoflagellate Karenia brevis blooms using satellite imagery," Opt. Express 17, 9126-9144 (2009)
# nLw678 - nLw667
### Karenia brevis bloom index (KBBI)
# (nLw678 - nLw667)/(nLw678 + nLw667)
# Rrs = nLw/F0
# Rrs: sr^-1; nLw: mW cm^-2 um^-1 sr^-1; F0: mW cm^-2 um^-1
sat_lll <- c(412,443,469,488,531,547,551,555,645,667,678,748,859,869,1240,1640,2130)
F0 <- c(172.912,187.622,205.878,194.933,185.747,186.539,186.539,183.869,157.811,152.255,148.052,128.065,97.174,95.824,45.467,23.977,9.885)

parms <- c('CHL_chlor_a','FLH_nflh','RRS_Rrs_443','RRS_Rrs_488','RRS_Rrs_531','RRS_Rrs_547','RRS_Rrs_555','RRS_Rrs_667','RRS_Rrs_678')
parm <- substr(parms,5,11)

url <- 'http://oceandata.sci.gsfc.nasa.gov/opendap/MODISA/L3SMI/2011/002/A2011002.L3m_DAY_RRS_Rrs_443_4km.nc'
# system.time(modis1 <- nc_open(url,readunlim=T,suppress_dimvals=F,return_on_error=T))
system.time(modis1 <- nc_open(url,readunlim=F,suppress_dimvals=T,return_on_error=T))
atts <- ncatt_get(modis1,0)
# names(atts)[-c(1,6,8,9,11:14,18:26,29:34,36:44,46:48,51,53,55,57:64)]
lon <- ncvar_get(modis1, 'lon')
lon_start <- which(lon>lonbox_w)[1]-1
lon_stop <- which(lon>lonbox_e)[1]
lon_count <- length(lon_start:lon_stop)
lat <- ncvar_get(modis1, 'lat')
lat_start <- which(lat<latbox_n)[1]-1
lat_stop <- which(lat<latbox_s)[1]
lat_count <- length(lat_start:lat_stop)
lon2 <- ncvar_get(modis1, 'lon',start=lon_start,count=lon_count)
lat2 <- ncvar_get(modis1, 'lat',start=lat_start,count=lat_count)

times1 <- rep(NA,length(2017:2020))
for(yr in 2017:2020){ # 2022-11-08; 2003-2016,2021 completed
  print(paste('Processing',yr, '...',Sys.time()))
  write(paste(Sys.time(), 'Processing',yr),'output.txt',append=T)
  ### reference date and julian days
  # yr <- 2021 # 2003:2021
  dates <- data.frame(date=ymd(seq(as.Date(paste0(yr,'-01-01')),as.Date(paste0(yr,'-12-31')),'day')),
                      yday=yday(ymd(seq(as.Date(paste0(yr,'-01-01')),as.Date(paste0(yr,'-12-31')),'day'))))
  ### create netcdf file
  # dimlon <- ncdim_def('Lon','degreesE',lon2)
  # dimlat <- ncdim_def('Lat','degreesN',lat2)
  # dates1 <- as.POSIXct(paste0(dates$date,00:00),tz='GMT')
  # dates2 <- as.numeric(dates1)/86400
  # # as.Date(dates2[1],origin='1970-01-01')
  # dimtime <- ncdim_def('Time','days since 1970-01-01',dates2)
  # chlor_a <- ncvar_def('chlor_a','mg m^-3',list(dimlon,dimlat,dimtime),-32767,"Chlorophyll Concentration, OCI Algorithm",prec='double',compression=5) # prec='float may be smaller'
  # nflh <- ncvar_def('nflh','W m^-2 um^-1 sr^-1',list(dimlon,dimlat,dimtime),-32767,"Normalized Fluorescence Line Height",prec='double',compression=5) # prec='float may be smaller'
  # rrs_443 <- ncvar_def('Rrs_443','sr^-1',list(dimlon,dimlat,dimtime),-32767,"Remote sensing reflectance at 443 nm",prec='double',compression=5) # prec='float may be smaller'
  # rrs_488 <- ncvar_def('Rrs_488','sr^-1',list(dimlon,dimlat,dimtime),-32767,"Remote sensing reflectance at 488 nm",prec='double',compression=5) # prec='float may be smaller'
  # rrs_531 <- ncvar_def('Rrs_531','sr^-1',list(dimlon,dimlat,dimtime),-32767,"Remote sensing reflectance at 531 nm",prec='double',compression=5) # prec='float may be smaller'
  # rrs_547 <- ncvar_def('Rrs_547','sr^-1',list(dimlon,dimlat,dimtime),-32767,"Remote sensing reflectance at 547 nm",prec='double',compression=5) # prec='float may be smaller'
  # rrs_555 <- ncvar_def('Rrs_555','sr^-1',list(dimlon,dimlat,dimtime),-32767,"Remote sensing reflectance at 555 nm",prec='double',compression=5) # prec='float may be smaller'
  # rrs_667 <- ncvar_def('Rrs_667','sr^-1',list(dimlon,dimlat,dimtime),-32767,"Remote sensing reflectance at 667 nm",prec='double',compression=5) # prec='float may be smaller'
  # rrs_678 <- ncvar_def('Rrs_678','sr^-1',list(dimlon,dimlat,dimtime),-32767,"Remote sensing reflectance at 678 nm",prec='double',compression=5) # prec='float may be smaller'
  # # modis_tmp <- nc_create('modis_tmp.nc',list(chlor_a,nflh,rrs_443,rrs_488,rrs_531,rrs_547,rrs_555,rrs_667,rrs_678))
  # modis_tmp <- nc_create(paste0('modisa_daily_',yr,'.nc'),list(chlor_a,nflh,rrs_443,rrs_488,rrs_531,rrs_547,rrs_555,rrs_667,rrs_678))
  # nc.copy.atts(modis1,0,modis_tmp,0,names(atts)[c(1,6,8,9,11:14,18:26,29:34,36:44,46:48,51,53,55,57:64)]) # not tested
  # ncatt_put(modis_tmp,0,"time_coverage_start",paste(dates1[1]))
  # ncatt_put(modis_tmp,0,"time_coverage_end",paste(dates1[length(dates1)]))
  # ncatt_put(modis_tmp,0,"modified_by",'Brendan Turley')
  
  data_yday <- array(NA,c(9,
                          length(lon2),
                          length(lat2),
                          nrow(dates)))
  pb <- txtProgressBar(min = 0, max = nrow(dates), style = 3)
  t1 <- system.time(
    for(i in 1:nrow(dates)){
      for(j in 1:length(parms)){
        url <- paste0('http://oceandata.sci.gsfc.nasa.gov/opendap/MODISA/L3SMI/',
                      yr,
                      '/',
                      sprintf("%03d",dates$yday[i]),
                      '/A',
                      yr,
                      sprintf("%03d",dates$yday[i]),
                      '.L3m_DAY_',
                      parms[j],
                      '_4km.nc')
        # modis <- try(nc_open(url))
        modis <- try(nc_open(url,readunlim=F,suppress_dimvals=T,return_on_error=F))
        if(class(modis)!='try-error'){
          data <- ncvar_get(modis,parm[j],start=c(lon_start,lat_start),count=c(lon_count,lat_count))
          # if(i==1){
          #   nc.copy.atts(modis,parm[j],modis_tmp,parm[j],c('name','units','dim','_FillValue','longname','prec')) # not tested
          # }
          nc_close(modis)
          data_yday[j,,,i] <- data
        } else {
          write(paste0(Sys.time(), ' Error (i = ',i,', j = ',j,') ', url),'output.txt',append=T)
        }
        rm(modis,data,url)
      }
      setTxtProgressBar(pb, i)
    }
  )
  write(paste(Sys.time(), 'Processed', yr, 'total time (sec):',t1[3]),'output.txt',append=T)
  times1[yr-2002] <- t1[3]
  # "2022-11-04 11:26:35 CDT"
  # user   system  elapsed 
  # 134.101   48.079 4389.390 
  
  ### fill netcdf file
  # ncvar_put(modis_tmp,chlor_a,data_yday[1,,,])
  # ncvar_put(modis_tmp,nflh,data_yday[2,,,])
  # ncvar_put(modis_tmp,rrs_443,data_yday[3,,,])
  # ncvar_put(modis_tmp,rrs_488,data_yday[4,,,])
  # ncvar_put(modis_tmp,rrs_531,data_yday[5,,,])
  # ncvar_put(modis_tmp,rrs_547,data_yday[6,,,])
  # ncvar_put(modis_tmp,rrs_555,data_yday[7,,,])
  # ncvar_put(modis_tmp,rrs_667,data_yday[8,,,])
  # ncvar_put(modis_tmp,rrs_678,data_yday[9,,,])
  # ncatt_put(modis_tmp,0,"last_Modified",paste(Sys.time()))
  # nc_close(modis_tmp)
  
  saveRDS(data_yday,paste0('modisa_daily_',yr,'.rds')) # netcdf is smaller and contains metadata
  # data_yday <- readRDS('modisa_daily_2021.rds')
}
cat('total time:',sum(times1,na.rm=T), 'sec')
# write(paste('Total time:',sum(times1,na.rm=T), 'sec (2017-2020)'),'output.txt',append=T)

par(mfrow=c(2,2))
for(i in 1:9){
  imagePlot(lon2,rev(lat2),
            log10(data_yday[i,,(dim(data_yday)[4]:1),1]),
            asp=1)
  mtext(parm[i])
}

# how much storage will this take?
# data_yday <- array(1000000,c(9,length(lon2),length(lat2),1))
# size <- object.size(data_yday)
#  # 1 day ~ 1.8 mb; 
# format(size*365*22,units='GB')
# format(size*365,units='GB')


# d) what derived parameters post-processing
# chl anomaly
chl_anom <- array(NA,c(length(75:365),length(lon2),length(lat2)))
for(i in 1:length(lon2)){
  for(j in 1:length(lat2)){
    n <- 1
    for(k in 75:365){
      ### 15 day lagged anomaly of 60 day mean
      lm_60d <- mean(chl_yday[(k-74):(k-74+59),i,j],na.rm=T)
      chl_anom[n,i,j] <- chl_yday[k,i,j] - lm_60d
      n <- n + 1
    }
  }
}
# corrected chl anomaly - rrs_667

### 2) match up to HAB monitoring data


### 3) match up to SST and bathymetry
# mur_sst_a <- info('jplMURSST41anommday')
# mur_sst <- info('jplMURSST41')
# oisst <- info('ncdcOisst21Agg')

### West Florida Shelf
lonbox_w <- -87.5 ### mouth of Mississippi River
latbox_n <- 30.7 ### northern coast
lonbox_e <- -81 ### Florida Bay
latbox_s <- 24.2 ### southern edge of Key West
latitude = c(latbox_s, latbox_n)
longitude = c(lonbox_w, lonbox_e)

url <- 'https://opendap.jpl.nasa.gov/opendap/OceanTemperature/ghrsst/data/GDS2/L4/GLOB/JPL/MUR/v4.1/2021/001/20210101090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04.1.nc'
data <- nc_open(url)
lon <- ncvar_get(data,'lon')
lon_ind <- which(lon>=lonbox_w & lon<=lonbox_e)
lon_tmp <- lon[lon_ind]
lat <- ncvar_get(data,'lat')
lat_ind <- which(lat>=latbox_s & lat<=latbox_n)
lat_tmp <- lat[lat_ind]
lon_start <- lon_ind[1]
lon_count <- length(lon_ind)
lat_start <- lat_ind[1]
lat_count <- length(lat_ind)
lonlat_t <- expand.grid(lon=lon_tmp,lat=lat_tmp)
lon_c <- cut(lonlat_t$lon,vec_brk(lon2))
lat_c <- cut(lonlat_t$lat,vec_brk(lat2))
lonlat <- expand.grid(lon=levels(lon_c),lat=levels(lat_c))

times1 <- rep(NA,length(2003:2021))
for(yr in 2003:2021){
  print(paste('Processing',yr, '...',Sys.time()))
  write(paste(Sys.time(), 'Processing MUR SST',yr),'output.txt',append=T)
  ### reference date and julian days
  # yr <- 2021 # 2003:2021
  dates <- data.frame(date=ymd(seq(as.Date(paste0(yr,'-01-01')),as.Date(paste0(yr,'-12-31')),'day')),
                      yday=yday(ymd(seq(as.Date(paste0(yr,'-01-01')),as.Date(paste0(yr,'-12-31')),'day'))))
  
  data_yday <- array(NA,c(length(lon2),
                          length(lat2),
                          nrow(dates)))
  pb <- txtProgressBar(min = 0, max = nrow(dates), style = 3)
  t1 <- system.time(
  for(i in 1:nrow(dates)){
    # url <- 'https://opendap.jpl.nasa.gov/opendap/OceanTemperature/ghrsst/data/GDS2/L4/GLOB/JPL/MUR/v4.1/2021/001/20210101090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04.1.nc'
    url <- paste0('https://opendap.jpl.nasa.gov/opendap/OceanTemperature/ghrsst/data/GDS2/L4/GLOB/JPL/MUR/v4.1/',
           yr,
           '/',
           sprintf("%03d",dates$yday[i]),
           '/',
           yr,
           sprintf("%02d",month(dates$date[i])),
           sprintf("%02d",day(dates$date[i])),
           '090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04.1.nc')  
    data <- try(nc_open(url,readunlim=F,suppress_dimvals=T,return_on_error=F))
    if(class(data)!='try-error'){
      time <- ymd_hms(ncatt_get(data,0)$start_time)
      # time <- ncvar_get(data,'time')
      # as.Date(time/(3600*24),origin=as.Date(substr(ncatt_get(data,'time')$units,15,40)))
      
      sst <- ncvar_get(data,'analysed_sst',
                       start=c(lon_start,lat_start,1),
                       count=c(lon_count,lat_count,-1))
      sst <- NISTkTOdegC(sst)
      sst_agg <- aggregate(as.vector(sst),by=list(lon=lon_c,lat=lat_c),mean,na.rm=T)
      sst_agg <- merge(lonlat,sst_agg,by=c('lon','lat'),all=T)
      sst_agg_m <- t(matrix(sst_agg$x,length(levels(lat_c)),length(levels(lon_c))))
      
      nc_close(data)
      data_yday[,,i] <- sst_agg_m
    } else {
      write(paste0(Sys.time(), ' Error MUR SST (i = ',i,') ', url),'output.txt',append=T)
    }
    rm(data,url,sst,sst_agg,sst_agg_m)
    setTxtProgressBar(pb, i)
  }
  )
  write(paste(Sys.time(), 'Processed MUR SST', yr, 'total time (sec):',t1[3]),'output.txt',append=T)
  times1[yr-2002] <- t1[3]
  
  saveRDS(data_yday,paste0('mursst_daily_',yr,'.rds')) # netcdf is smaller and contains metadata
}
cat('total time:',sum(times1,na.rm=T), 'sec')
write(paste('Total time:',sum(times1,na.rm=T), 'sec (2002-2021)'),'output.txt',append=T)



### bathymetry
url <- 'https://www.ngdc.noaa.gov/thredds/dodsC/global/ETOPO2022/60s/60s_bed_elev_netcdf/ETOPO_2022_v1_60s_N90W180_bed.nc'
## higher resolution
# url <- 'https://www.ngdc.noaa.gov/thredds/dodsC/global/ETOPO2022/30s/30s_bed_elev_netcdf/ETOPO_2022_v1_30s_N90W180_bed.nc''
data <- nc_open(url)
lon <- ncvar_get(data,'lon')
lon_ind <- which(lon>=lonbox_w & lon<=lonbox_e)
lon_tmp <- lon[lon_ind]
lat <- ncvar_get(data,'lat')
lat_ind <- which(lat>=latbox_s & lat<=latbox_n)
lat_tmp <- lat[lat_ind]
lon_start <- lon_ind[1]
lon_count <- length(lon_ind)
lat_start <- lat_ind[1]
lat_count <- length(lat_ind)
lonlat <- expand.grid(lon=lon_tmp,lat=lat_tmp)
lon_c <- cut(lonlat$lon,vec_brk(lon2))
lat_c <- cut(lonlat$lat,vec_brk(lat2))
lonlat <- expand.grid(lon=levels(lon_c),lat=levels(lat_c))

bathy <- ncvar_get(data,'z',
                 start=c(lon_start,lat_start),
                 count=c(lon_count,lat_count))
bathy[which(bathy>0)] <- NA
bathy <- (-bathy)
imagePlot(log10(bathy),asp=1)

bathy_agg <- aggregate(as.vector(bathy),by=list(lon=lon_c,lat=lat_c),mean,na.rm=T)
bathy_agg <- merge(lonlat,bathy_agg,by=c('lon','lat'),all=T)
bathy_agg_m <- t(matrix(bathy_agg$x,length(levels(lat_c)),length(levels(lon_c))))
imagePlot(log10(bathy_agg_m),asp=1)

### 4) variable selection


### 5) create model


### 6) validate model


