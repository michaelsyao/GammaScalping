# GammaScalping
Option Strategy for Futures. This is a event-driven strategy.

## I. Definition
### **Project Overview**
This project is to replicate the training strategy from a workshop.

### **Strategy 1: Shorting Crude Oil Futures Option Straddle**
Short a straddle on the day after the release date of a “US Weekly Petroleum Status Report,” and buy a cover just before the next release. But as with any options strategy, especially strategies that trade intraday, the implementation details can be staggering. This will be a good example of some of the issues we face.

### **Strategy 2: Gamma scalping crude oil futures
A formal definition of MSE can be seen as below ([Wikipedia](https://en.wikipedia.org/wiki/Mean_squared_error)):

> In statistics, the mean squared error (MSE) or mean squared deviation (MSD) of an estimator (of a procedure for estimating an unobserved quantity) measures the average of the squares of the errors or deviations—that is, the difference between the estimator and what is estimated.

## II. Analysis
### Data Exploration and Preprocessing

Let’s first talk about the source of data I am going to be using. Keeping the main focus of this project on building models, I will try to keep the data-pipeline as lean as possible. ```Quandl``` has a neat API which allows users to download single-name historical OHLC prices and volumes easily. I will be using ```pandas-datareader``` to request OHLC price dataframes from Quandl.

Specifically, I will be using stock prices of Apple but this study can easily be extended to any other equity that can be pulled via Quandl. Since APPL has been around for a long time I will try to go back as much as possible and although their IPO was in 1980, I will limit the data to the beginning of 1990 which should be fairly long history to capture events like Tech crash and 08’ crisis. Furthermore, I will use the most recent 10% of the data as my test set and the remaining 90% will be split 90-10 as training and validation sets.

![historical_px.png](./assets/historical_px.png)

Before we make any adjustments to the raw data let's take a look at the distributions of the estimators and how they compare amongst one another.

```Matlab
import pandas_datareader.data as web

# _ get data from Quandl
eq = web.DataReader('AAPL', 'quandl', '1990-01-01', '2017-12-31')
eq = eq[['AdjOpen', 'AdjHigh', 'AdjLow', 'AdjClose', 'AdjVolume']]
eq.sort_index(inplace=True)
