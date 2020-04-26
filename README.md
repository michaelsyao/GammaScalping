# GammaScalping
Option Strategy for Futures. This is a event-driven strategy.The Basic concept as follows:
>1.Buy a staddle (LC + LP)
>2.Perfectly delta neutral
>3.Underlying falls? Add long stock
>4.Underlying rises? Add short stock.

## I. Definition
### **Project Overview**
This project is to replicate the training strategy from a workshop and overcome the potential issue of Strategy 1.

### **Strategy 1: Shorting Crude Oil Futures Option Straddle**
Short a straddle on the day after the release date of a “US Weekly Petroleum Status Report,” and buy a cover just before the next release. 

Crude oil futures (symbol CL) on CME Globex expire around the 22th of every month ahead of the delivery month. For example, the February 2015 contract (denoted as CLG15) will cease trading on or around January 22, 2015. However, its options (symbol LO) expire three (3) business days ahead. Note that we trade only options on the front (nearest to expiration) futures contract, but at the same time we require the option to have a tenor (time‐to‐maturity) of about two weeks. The option expiration date is approximate only, and the first trading date of J12 and the last trading date of J13 are irregular due to the limitation of our data. Furthermore, there is no guarantee that this choice of tenor produces the optimal returns: It should be treated as a parameter to be optimized. (Similarly, the exact entry and exit dates and times are free parameters to be optimized, too.) The data are from Nanex.net.

As a straddle consists of one pair of an ATM put and call, we need to find out what strike price is ATM at the moment of the trade entry. Hence, we need to first retrieve the quotes data for the underlying CL futures contracts and determine the midprice at 9:00 a.m. Eastern Time on Thursdays. Notice that this is already a simplification: We have treated those holiday weeks when the releases were on Thursdays at 11:00 a.m. in the same way as the regular weeks. But if anything, this will only deflate our backtest performance, which gives us a more conservative estimate of the strategy profitability. In case either a Thursday and the following Wednesday is not a trading day, our code will take care not to enter into a position. After finding the underlying future's midprice and

### **Strategy 2: Gamma Scalping Crude Oil Futures**
Short a straddle on the day after the release date of a “US Weekly Petroleum Status Report,” and buy a cover just before the next release. But as with any options strategy, especially strategies that trade intraday, the implementation details can be staggering. This will be a good example of some of the issues we face.

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
