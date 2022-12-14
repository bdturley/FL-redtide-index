gc()

library(caret)
library(fields)
library(lubridate)
library(mgcv)
library(pROC)
library(randomForest)
library(scales)

setwd('~/Documents/nasa/data/lowres_4km')
# write.csv(habs_covar_agg,'habs_covariates_agg.csv',row.names = F)
habs_covar_agg <- read.csv('habs_covariates_agg.csv')
habs_covar_agg$date <- ymd(habs_covar_agg$date)

### proportion positive
length(which(habs_covar_agg$pa100k==1))/nrow(habs_covar_agg)
# 0.06695985
# 0.06604714 'raw' FWC dataset proportion positive

plot(habs_covar_agg$LONGITUDE[which(habs_covar_agg$pa100k==0)],habs_covar_agg$LATITUDE[which(habs_covar_agg$pa100k==0)],asp=1,pch=20,cex=.7)
points(habs_covar_agg$LONGITUDE[which(habs_covar_agg$pa100k==1)],habs_covar_agg$LATITUDE[which(habs_covar_agg$pa100k==1)],col=4,pch=20,cex=.7)

### plot data
look <- habs_covar_agg[,-c(1:8,22:26)]

par(mfrow=c(2,1),mar=c(4,4,1,1))
for(i in 1:ncol(look)){
  plot(habs_covar_agg$date,look[,i],
       xlab='date',ylab=paste(names(look)[i]),
       pch=20,col=alpha(1,.1),cex=.8,xaxt='n')
  abline(v=as.Date(paste0(2000:2022,'-01-01')),lty=5,col='gray50')
  abline(h=0,lty=5,col='gray70')
  sp <- smooth.spline(habs_covar_agg$date,look[,i],spar=.6)
  points(sp$x,sp$y,col=2,typ='l',lwd=2)
  axis(1,as.Date(paste0(seq(2000,2022,1),'-01-01')),seq(2000,2022,1),las=2)
}

dates <- data.frame(date=seq(as.Date('2003-01-01'),as.Date('2003-12-31'),'day'),yday=yday(seq(as.Date('2003-01-01'),as.Date('2003-12-31'),'day')))
ind <- which(day(dates$date)==1)
par(mfrow=c(2,1),mar=c(4,4,1,1))
for(i in 1:ncol(look)){
  plot(habs_covar_agg$yday,look[,i],
       xlab='date',ylab=paste(names(look)[i]),
       pch=20,col=alpha(1,.1),cex=.8,xaxt='n')
  abline(v=ind,lty=5,col='gray50') 
  abline(h=0,lty=5,col='gray70')
  sp <- smooth.spline(habs_covar_agg$yday,look[,i],spar=.6)
  points(sp$x,sp$y,col=2,typ='l',lwd=2)
  axis(1,ind,month.abb[1:12])
}

res <- p_val <- matrix(NA,ncol(look),ncol(look))
for(i in 1:ncol(look)){
  for(j in 1:ncol(look)){
    tmp <- cor.test(look[,i],look[,j],method='spearman')
    res[i,j] <- tmp$estimate
    p_val[i,j] <- tmp$p.value
  }
}
row.names(res) <- colnames(res) <- names(look)
# diag(res) <- NA
# diag(p_val) <- NA
# res[which(p_val>.05/(length(which(!is.na(res)))))] <- NA

lm_neg <- colorRampPalette(c('dodgerblue4','deepskyblue3','lightskyblue1','gray95'))
lm_pos <- colorRampPalette(c('gray95','rosybrown1','tomato2','red4'))
brks <- seq(-1,1,.1)
neg <- lm_neg(length(which(brks<0)))
pos <- lm_pos(length(which(brks>0)))
res2 <- res
res2[lower.tri(res2,diag=T)] <- NA

par(mar=c(1,6,6,3),pin=c(3,3))
imagePlot(1:14,1:14,res2,
          breaks=brks,col=c(neg,pos),
          xaxt='n',yaxt='n',xlab='',ylab='',asp=1)
axis(2,2:14,names(look)[-1],las=1)
axis(3,1:13,names(look)[-14],las=2)

sort(rowSums(abs(res)))

heatmap(res,symm=F)

clust <- hclust(as.dist(1-res))
plot(clust)

dend <- as.dendrogram(clust)
plot(dend)

# pca1 <- princomp(look)
# loadings(pca1)
# biplot(pca1)
# plot(pca1)

### random forest
# https://www.r-bloggers.com/2021/04/random-forest-in-r/
# https://stats.stackexchange.com/questions/41443/how-to-actually-plot-a-sample-tree-from-randomforestgettree
# https://cran.rstudio.com/web/packages/randomForestExplainer/vignettes/randomForestExplainer.html
set.seed(222)
ind <- sample(2, nrow(habs_covar_agg), replace = TRUE, prob = c(.5, .5))
names(habs_covar_agg)[c(1:3,6:8)]
habs_covar_agg$pa100k <- as.factor(habs_covar_agg$pa100k)
train <- habs_covar_agg[ind==1,-c(1:3,6:8)] # remove all superfluous variables
test <- habs_covar_agg[ind==2,-c(1:3,6:8)]
rf <- randomForest(pa100k~., data=train, proximity=T, importance=T) # norm.votes = F for combining trees


set.seed(222)
ind <- sample(3, nrow(habs_covar_agg), replace = TRUE, prob = c(.35,.35, .3))
names(habs_covar_agg)[c(1:3,6:8)]
habs_covar_agg$pa100k <- as.factor(habs_covar_agg$pa100k)
train <- habs_covar_agg[ind==1,-c(1:3,6:8)] # remove all superfluous variables
train2 <- habs_covar_agg[ind==2,-c(1:3,6:8)]
test <- habs_covar_agg[ind==3,-c(1:3,6:8)]

# rf <- randomForest(pa100k~LATITUDE+LONGITUDE+chlor_a+chl_anom+nflh+nflh_anom+rrs_667+abi+bbp_carder+bbp_morel+ssnlw488+rbd+kbbi+cm_bbp+sst+year+month+yday+week+depth_m,data=train, proximity=T, importance=T)
remove <- sample(nrow(train2),nrow(train2)-nrow(train),replace=F)
train2 <- train2[-remove,]
rf1 <- randomForest(pa100k~., data=train, proximity=T, importance=T, norm.votes = F) # norm.votes = F for combining trees
rf2 <- randomForest(pa100k~., data=train2, proximity=T, importance=T, norm.votes = F)
rf.all <- combine(rf1, rf2)
# Error: vector memory exhausted (limit reached?)
# https://stackoverflow.com/questions/17052436/does-random-forest-in-r-have-a-limitation-of-size-of-training-data
setwd('~/Documents/nasa/data/lowres_4km')
save(rf, file = "randomForest_initial.RData")
# load('randomForest_initial.RData')
print(rf)
print(rf2)
print(rf.all)
# print(object.size(rf),units='Mb')
hist(treesize(rf.all),main = "No. of Nodes for the Trees",col = "green")
plot(randomForest::margin(rf.all),sort=T)
### tune
rf_tune <- tuneRF(train[,-20],  train[,20],
                  stepFactor = 2, plot = TRUE, ntreeTry = 150, trace = TRUE, improve = .05)

# https://topepo.github.io/caret/measuring-performance.html
p1 <- predict(rf.all, train)
confusionMatrix(p1, train$pa100k,positive='1')
p2 <- predict(rf.all, test)
tabs <- addmargins(table(p2,test$pa100k))
tabs
error_mat <- confusionMatrix(p2, test$pa100k, positive='1', mode='everything')
error_mat
error_mat$byClass # F1 out of 1; https://en.wikipedia.org/wiki/F-score; https://en.wikipedia.org/wiki/Sensitivity_and_specificity
### 2022/12/07 - there is a high specificity (few false positives) and low sensitivity (many false negatives); the opposite of what is desired
tabs[1,2]/tabs[3,2] # FNR or 1 - sensitivity
tabs[2,1]/tabs[3,1] # FPR or 1 - specificity

plot(rf.all,log='y')
legend('topright',c('OOB','Neg','Pos'),col=c(1,2,3),lty=1)

### ROC analysis
p3 <- predict(rf.all, test, type='prob')
temproc <- roc(test$pa100k , p3[,2], plot=TRUE, grid=TRUE)
# CALCULATE AREA UNDER THE CURVE
temproc$auc  

yr <- 2005
subset <- test[which(test$year==yr ),]
phat1 <- p3[,2][which(test$year==yr )]

par(mar=c(5,5,1,6))
plot(subset$LONGITUDE,subset$LATITUDE,asp=1)
quilt.plot(subset$LONGITUDE,subset$LATITUDE,phat1,col=plasma(60),asp=1,add=T)


var_imp <- importance(rf.all,scale=T)
var_imp
par(mar=c(4,7,1,1))
barplot(sort(var_imp[,1]),las=1,horiz=T,main='Importance (absence)')
barplot(sort(var_imp[,2]),las=1,horiz=T,main='Importance (presence)')
barplot(t(var_imp[,1:2]),las=1,horiz=T,col=c('gray20','gray80'),beside=F)
legend('bottomright',c('absence','presence'),fill=c('gray20','gray80'),bty='n')
plot(var_imp[,3],var_imp[,4],typ='n',xlab='MeanDecreaseAccuracy',ylab='MeanDecreaseGini')
text(var_imp[,3],var_imp[,4],row.names(var_imp),cex=.8)

png('rti_rf_varimp.png',width=9,height=7,pointsize=12,unit='in',res=300)
varImpPlot(rf.all,
           sort = T,
           main = "Variable Importance")
dev.off()

var_imp2 <- varImp(rf.all,scale=T)
barplot(sort(var_imp2[,2]),names.arg = rownames(var_imp2)[order(var_imp2[,2])],las=2,horiz=T)

par(mfrow=c(2,2))
plot(var_imp[,3],var_imp[,4],typ='n',xlab='MeanDecreaseAccuracy',ylab='MeanDecreaseGini')
text(var_imp[,3],var_imp[,4],row.names(var_imp),cex=.8)

plot(var_imp[,3],var_imp2[,2],typ='n',xlab='MeanDecreaseAccuracy',ylab='VarImp (caret)')
text(var_imp[,3],var_imp2[,2],row.names(var_imp),cex=.8)

plot(var_imp2[,2],var_imp[,4],typ='n',xlab='VarImp (caret)',ylab='MeanDecreaseGini')
text(var_imp2[,2],var_imp[,4],row.names(var_imp),cex=.8)

ind_var <- rownames(var_imp)[order(var_imp[,4],decreasing=T)]
# pdf('rti_rf_partial.pdf',width=9,height=7,pointsize=12)
par(mfrow=c(3,3),mar=c(4,4,1,1))
for (i in seq_along(ind_var)) {
  partialPlot(rf, train, ind_var[i], xlab=ind_var[i],
              main=paste("Partial Dependence on", ind_var[i]),rug=T)
}
# dev.off()

### initial model check
covar <- names(habs_covar_agg)[c(9:22,24:25,27)]

for(i in 1:length(covar)){
  x_y <- formula(paste0('pa100k~',covar[i]))
  mod1 <- glm(x_y,data=habs_covar_agg,family=binomial(link='logit'))
  print(x_y)
  print(summary(mod1))
  cat('\n\n************ANOVA************\n\n')
  print(anova(mod1,test='Chisq'))
  cat('\n\n************END************\n\n')
}

mod1 <- glm(pa100k~as.factor(month),data=habs_covar_agg,family=binomial(link='logit'))
summary(mod1)
anova(mod1,test='Chisq')

par(mfrow=c(3,3))
for(i in c(4:5,9:25,27)){
  plot(habs_covar_agg[,i],habs_covar_agg$pa100k)
  # plot(habs_covar_agg[,i],habs_covar_agg$CELLCOUNT+1,log='y')
  mtext(names(habs_covar_agg)[i])
}

mod0 <- glm(pa100k~as.factor(month)+chlor_a+chl_anom+rbd+nflh+nflh_anom+ssnlw488+cm_bbp+morel_bbp+carder_bbp+abi+rrs_667,
            data=habs_covar_agg,family=binomial(link='logit'))
summary(mod0)
anova(mod0,test='Chisq')
mod1 <- glm(pa100k~as.factor(month)+chlor_a+chl_anom+rbd+nflh+ssnlw488+cm_bbp+carder_bbp+abi,
            data=habs_covar_agg,family=binomial(link='logit'))
summary(mod1)
anova(mod1,test='Chisq')

preds <- predict(mod1,newdata=habs_covar_agg,se.fit=T,type='response')
preds$month <- aggregate(preds$fit,by=list(habs_covar_agg$month),mean,na.rm=T)
preds$month.se <- aggregate(preds$se.fit,by=list(habs_covar_agg$month),mean,na.rm=T)
preds$year <- aggregate(preds$fit,by=list(habs_covar_agg$year),mean,na.rm=T)
preds$year.se <- aggregate(preds$se.fit,by=list(habs_covar_agg$year),mean,na.rm=T)

covar <- names(habs_covar_agg)[c(9:11,14:15,17:18,20)]

par(mfrow=c(3,3))
for(i in c(9:11,14:15,17:18,20)){
  plot(habs_covar_agg[,i],preds$fit)
  mtext(names(habs_covar_agg)[i])
}

plot(preds$month$Group.1,preds$month$x,pch=18,ylim=c(0,.2))
arrows(preds$month$Group.1,preds$month$x+preds$month.se$x,
       preds$month$Group.1,preds$month$x-preds$month.se$x,length=.105,code=3,angle=90)

plot(preds$year$Group.1,preds$year$x,pch=18,ylim=c(0,.2),typ='n')
# arrows(preds$year$Group.1,preds$year$x+preds$year.se$x,
# preds$year$Group.1,preds$year$x-preds$year.se$x,length=.105,code=3,angle=90)
polygon(c(preds$year$Group.1,rev(preds$year$Group.1)),
        c(preds$year$x+preds$year.se$x,rev(preds$year$x-preds$year.se$x)),col='gray90')
points(preds$year$Group.1,preds$year$x,pch=18,typ='l')


### ROC analysis
temproc <- roc(habs_covar_agg$pa100k , preds$fit, plot=TRUE, grid=TRUE)
# CALCULATE AREA UNDER THE CURVE
temproc$auc  
# Area under the curve: 0.6629
# CONSTRUCT MATRIX OF ROC INFORMATION FOR EACH CUTOFF ("thresholds")	 
roctable <- cbind(temproc$sensitivities, temproc$specificities, temproc$thresholds, 
                  temproc$sensitivities+temproc$specificities)
# FIND CUTOFF WHERE SUM OF THE SENSITIVITY AND SPECIFITY IS MAX
# Sensitivity = proportion of actual positives which are correctly identified as such
# Specificity = proportion of negatives which are correctly identified as such
max(roctable[,1]+roctable[,2])
# [1] 1.241529
# PRINT RECORD FOR THE MAX VALUE TO FIND CUTOFF (= 0.0862855  HERE)
Threshold=roctable[roctable[,4] == max(roctable[,4]),][3]
Threshold 
# [1] 0.07898927
TT=table(mod1$fitted>Threshold, habs_covar_agg$pa100k)
#           0     1
# FALSE 32116   809
# TRUE   7346  2023
FPR =  TT[2,1]/sum(TT[ ,1 ]) 
FNR =   TT[1,2]/sum(TT[ ,2 ])    
FPR # 0.1861538
FNR # 0.2856638

yr <- 2005
subset <- habs_covar_agg[which(habs_covar_agg$year==yr ),]
phat1 <- preds$fit[which(habs_covar_agg$year==yr )]

par(mar=c(5,5,1,6))
plot(subset$LONGITUDE,subset$LATITUDE,asp=1)
quilt.plot(subset$LONGITUDE,subset$LATITUDE,phat1,col=plasma(60),asp=1,add=T)


### GAMs
AllModel  <- gam(as.factor(pa100k) ~ as.factor(month) + te(chl_anom,week) + te(chlor_a,week) + te(bbp_carder,bbp_morel) + 
                   te(sst, depth_m) + te(rrs_667,week) + te(LONGITUDE,LATITUDE) + te(rbd,week) + te(depth_m), 
                 data=habs_covar_agg, family = binomial, select=TRUE, method="REML")
setwd('~/Documents/nasa/data/lowres_4km')
save(AllModel, file = "AllModelgam_initial.RData")
load('AllModelgam_initial.RData')
p <- plot(AllModel, pages=1, se=TRUE, cex.axis=2, cex.lab=1.5)
summary(AllModel)


