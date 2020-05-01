%Strategy 2
% Long LO straddle at Thursday 9:00, exit at Fri 14:30.
% Mean reversion on CL

clear;

entryDay=5; % Thurs
exitDay=6; % Fri

entryTime=900;
exitTime=1430;

numLevels=1; % 1 levels for CL
levelWidth=0.01; % Each level is 1%

otm=0.05; % otm should be (1+numLevels)*levelWidth

contracts={...
    'J12', ...
    'K12', ...
    'M12', ...
    'N12', ...
    'Q12', ...
    'U12', ...
    'V12', ...
    'X12', ...
    'Z12', ...
    'F13', ...
    'G13', ...
    'H13', ...
    'J13'};

dateRanges={...
    '20120301_20120331', ...
    '20120310_20120409', ...
    '20120410_20120509', ...
    '20120510_20120620', ...
    '20120610_20120720', ...
    '20120704_20120809', ...
    '20120804_20120909', ...
    '20120904_20121015', ...
    '20121004_20121115', ...
    '20121104_20121215', ...
    '20121204_20130115', ...
    '20130104_20130215', ...
    '20130204_20130227'};

firstDateTimes={...
 '20120301 08:30:00', ...
    '20120306 08:30:00', ...
    '20120406 08:30:00', ...
    '20120506 08:30:00', ...
    '20120606 08:30:00', ...
    '20120706 08:30:00', ...
    '20120806 08:30:00', ...
    '20120906 08:30:00', ...
    '20121006 08:30:00', ...
    '20121106 08:30:00', ...
    '20121206 08:30:00', ...
    '20130106 08:30:00', ...
    '20130206 08:30:00'};

lastDateTimes={...
   '20120305 10:30:00', ...
    '20120405 10:30:00', ...
    '20120505 10:30:00', ...
    '20120605 10:30:00', ...
    '20120705 10:30:00', ...
    '20120805 10:30:00', ...
    '20120905 10:30:00', ...
    '20121005 10:30:00', ...
    '20121105 10:30:00', ...
    '20121205 10:30:00', ...
    '20130105 10:30:00', ...
    '20130205 10:30:00', ...
    '20130305 10:30:00'};

assert(length(contracts)==length(dateRanges));
assert(length(contracts)==length(firstDateTimes));
assert(length(contracts)==length(lastDateTimes));

fidout=fopen(['C:/Projects/Options_data/gammaScalp_strangle_LO_', num2str(numLevels), 'levels_', num2str(100*otm), 'otm_execs.csv'], 'w');

cumPL=0;
cumPL_Fut=0;
for c=1:length(contracts)
    contract=contracts{c};
    dateRange=dateRanges{c};
    firstDateTime=firstDateTimes{c};
    lastDateTime=lastDateTimes{c};
        
    % Get futures price to determine what strike price is ATM
    load(['//I3/Futures_data/inputData_CL', contract, '_BBO_', dateRange, '.mat'], 'dn', 'bid', 'ask');
    
    goodData=dn >= datenum(firstDateTime, 'yyyymmdd HH:MM:SS') & dn <= datenum(lastDateTime, 'yyyymmdd HH:MM:SS');
    
    dnFut=dn(goodData);
    bidFut=bid(goodData);
    askFut=ask(goodData);
    
    clear dn bid ask;
    
    midFut=(bidFut+askFut)/2;
    
    len=1000000;
        
    hhmm=str2double(cellstr(datestr(dnFut, 'HHMM')));
    hhmmssfffFut=cellstr(datestr(dnFut, 'HH:MM:SS.FFF'));
    
    isEntryFut=backshift(1, hhmm) < entryTime &  hhmm >= entryTime & weekday(dnFut')==entryDay;

    opn=midFut(isEntryFut);
    yyyymmddFut=yyyymmdd(datetime(dnFut, 'ConvertFrom', 'datenum'));
    yyyymmddEntry=yyyymmddFut(isEntryFut);
    %     yyyymmddExit=yyyymmddFut(isExitFut);
    
    isEntryFutIdx=find(isEntryFut);

    roundPrice=@(x) round(2*x)/2; % round(x/minIncrement)*minIncrement
    padzero=@(x) [char(repmat('0', [1 5-length(x)])), x]; 
    assert(length(yyyymmddFut)==length(hhmmssfffFut));
    
    % Iterate through each event date
    for d=1:length(opn)
        %% Mean reversion strategy on CL
        isExitFut= hhmm < exitTime & yyyymmddFut' > yyyymmddEntry(d) & weekday(dnFut')==exitDay;
        isExitFutIdx=find(isExitFut);
        if (isempty(isExitFutIdx))
            fprintf(1, '    ***Cannot find futures exit date: skipping entry on %i!\n', yyyymmddEntry(d));
            continue; % Do not enter on this event
        end

        ie=find(dnFut(isExitFutIdx)-dnFut(isEntryFutIdx(d)) > 1 & dnFut(isExitFutIdx)-dnFut(isEntryFutIdx(d)) < 1.5);
        if (isempty(ie))
            fprintf(1, '    ***Cannot find futures exit date: skipping entry on %i!\n', yyyymmddEntry(d));
            continue; % Do not enter on this event
        end
        ie=ie(end);
               
        idx=isEntryFutIdx(d):isExitFutIdx(ie); 
        retFut_bid=(bidFut(idx)-opn(d))/opn(d);
        retFut_ask=(askFut(idx)-opn(d))/opn(d);
        
        PL_Fut=0;
        maxLevelReached=0;
        for entryThreshold=levelWidth:levelWidth:numLevels*levelWidth
            exitThreshold=entryThreshold-levelWidth;
            
            pos_Fut=NaN(length(idx), 1);
            pos_Fut(1)=0;
            pos_Fut_L=pos_Fut;
            pos_Fut_S=pos_Fut;
            
            pos_Fut_S(retFut_bid > entryThreshold)=-1;
            pos_Fut_S(retFut_ask <= exitThreshold)=0;
            pos_Fut_S=fillMissingData(pos_Fut_S);
            
            pos_Fut_L(retFut_ask < -entryThreshold)=1;
            pos_Fut_L(retFut_bid >= -exitThreshold)=0;
            pos_Fut_L=fillMissingData(pos_Fut_L);
            
            pos_Fut=pos_Fut_L+pos_Fut_S;
            pos_Fut(end)=0;
            
            if (any(abs(pos_Fut)==1))
                maxLevelReached=round(entryThreshold/levelWidth);
            end
            
            for i=2:length(idx)
                myidx=idx(i);
                if (pos_Fut(i-1)==0 && pos_Fut(i) > pos_Fut(i-1)) % Buy entry
                    entryPrice=(bidFut(myidx)+askFut(myidx))/2; % Enter at mid-quote
                    fprintf(fidout,'CL_%s_FUT,%i,%s,Bought,%f,1,0\n',   contract, yyyymmddFut(myidx), char(hhmmssfffFut(myidx)), entryPrice);
                elseif (pos_Fut(i-1)==0 && pos_Fut(i) < pos_Fut(i-1)) % Short entry
                    entryPrice=(bidFut(myidx)+askFut(myidx))/2;
                    fprintf(fidout,'CL_%s_FUT,%i,%s,Sold,%f,1,0\n',   contract, yyyymmddFut(myidx), char(hhmmssfffFut(myidx)), entryPrice);
                elseif (pos_Fut(i-1) > 0 && pos_Fut(i) < pos_Fut(i-1)) % Sell long
                    exitPrice=bidFut(myidx); % Exit at MKT
                    fprintf(fidout,'CL_%s_FUT,%i,%s,Sold,%f,1,0\n',   contract, yyyymmddFut(myidx), char(hhmmssfffFut(myidx)), exitPrice);

                    PL_Fut=PL_Fut+(exitPrice-entryPrice);
                    if (pos_Fut(i) < 0) % Short entry
                        entryPrice=(bidFut(myidx)+askFut(myidx))/2;
                        fprintf(fidout,'CL_%s_FUT,%i,%s,Sold,%f,1,0\n',   contract, yyyymmddFut(myidx), char(hhmmssfffFut(myidx)), entryPrice);
                    end
                elseif (pos_Fut(i-1) < 0 && pos_Fut(i) > pos_Fut(i-1)) % Buy cover
                    exitPrice=askFut(myidx);
                    fprintf(fidout,'CL_%s_FUT,%i,%s,Bought,%f,1,0\n',   contract, yyyymmddFut(myidx), char(hhmmssfffFut(myidx)), exitPrice);

                    PL_Fut=PL_Fut-(exitPrice-entryPrice);
                    if (pos_Fut(i) > 0) % Buy entry
                        entryPrice=(bidFut(myidx)+askFut(myidx))/2;
                        fprintf(fidout,'CL_%s_FUT,%i,%s,Bought,%f,1,0\n',   contract, yyyymmddFut(myidx), char(hhmmssfffFut(myidx)), entryPrice);
                    end
                end
                
                
            end
            
        end
        %%

        %% Options
        stkPriceOTMCallStr=num2str(roundPrice(opn(d)*(1+otm)));
        stkPriceOTMPutStr=num2str(roundPrice(opn(d)*(1-otm)));
        
        if (isempty(regexp(stkPriceOTMCallStr, '\.')))
            stkPriceOTMCallStr=[stkPriceOTMCallStr, '00'];
        elseif (isempty(regexp(stkPriceOTMCallStr, '\.\d\d')))
            stkPriceOTMCallStr=regexprep(stkPriceOTMCallStr, '\.', '');
            stkPriceOTMCallStr=[stkPriceOTMCallStr, '0'];
        else
            stkPriceOTMCallStr=regexprep(stkPriceOTMCallStr, '\.', '');
        end
        
        if (isempty(regexp(stkPriceOTMPutStr, '\.')))
            stkPriceOTMPutStr=[stkPriceOTMPutStr, '00'];
        elseif (isempty(regexp(stkPriceOTMPutStr, '\.\d\d')))
            stkPriceOTMPutStr=regexprep(stkPriceOTMPutStr, '\.', '');
            stkPriceOTMPutStr=[stkPriceOTMPutStr, '0'];
        else
            stkPriceOTMPutStr=regexprep(stkPriceOTMPutStr, '\.', '');
        end
        
        %% Call
        fid=fopen(['//I3//Options_data/LO.', contract, '/pLO', contract, stkPriceOTMCallStr, 'C_BBO_', dateRange, '.csv']);
        assert(fid~=-1);
        
        dn1=[];
        bid1=[];
        ask1=[];
        
        while (1)
            C=textscan(fid, '%u%s%f%f', len, 'Delimiter', ',');
            if (isempty(C))
                break;
            end
            if (length(C{1, 1})==0)
                break;
            end
            
            tday=num2str(C{1, 1});
            hhmmssfff=C{1, 2};
            
            bid1=[bid1; C{1, 3}];
            ask1=[ask1; C{1, 4}];
            
            dn1=[dn1; datenum(cellstr([tday, repmat(' ', size(hhmmssfff)), char(hhmmssfff)]), 'yyyymmdd HH:MM:SS.FFF')];
        end
        
        fclose(fid);
        
        %%%
        
        bid=NaN(size(bid1));
        ask=NaN(size(bid));
        dn=NaN(size(bid));
        
        t=1;
        t1=1;
        
        % Assume prices with same time stamp are in chronological order.
        while (t1 <= length(dn1) )
            if (bid1(t1) ~= 0 && ask1(t1) ~= 0)
                bid(t, 1)=bid1(t1);
                ask(t, 1)=ask1(t1);
                dn(t)=dn1(t1);
                t=t+1;
            end
            t1=t1+1;
        end
        
        lastGoodData=find(isfinite(dn));
        lastGoodData=lastGoodData(end);
        
        dn=dn(1:lastGoodData)';
        bid=bid(1:lastGoodData, :);
        ask=ask(1:lastGoodData, :);
        
        % Forward-fill quote prices when there are no new ticks.
        bid=fillMissingData(bid);
        ask=fillMissingData(ask);
        
        goodData=dn >= datenum(firstDateTime, 'yyyymmdd HH:MM:SS') & dn <= datenum(lastDateTime, 'yyyymmdd HH:MM:SS');
        
        dn=dn(goodData);
        bid=bid(goodData);
        ask=ask(goodData);
        
        hhmmCall=str2double(cellstr(datestr(dn, 'HHMM')));
        yyyymmddCall=yyyymmdd(datetime(dn, 'ConvertFrom', 'datenum'))';
        
        isEntry=hhmmCall < entryTime & yyyymmddCall==yyyymmddEntry(d);
        if (isempty(isEntry))
            fprintf(1, '    Missing call data on entry date %i: skipping...\n', yyyymmddEntry(d));
            continue;
        end

        isExit=hhmmCall < exitTime & yyyymmddCall > yyyymmddEntry(d) & weekday(dn')==exitDay;
        isEntryIdx=find(isEntry);
        isEntryIdx=isEntryIdx(end); % use latest entry 
        isExitIdx=find(isExit);
                     
        % Confirm futures dates are same as entry dates for options
        assert(yyyymmddEntry(d)==str2double(datestr(dn(isEntryIdx), 'yyyymmdd')));
        
        % Pick farthest exit date that is within a calendar week but more
        % than 1 calendar day % Fix this in book3!
        ie=find(dn(isExitIdx)-dn(isEntryIdx) > 1 & dn(isExitIdx)-dn(isEntryIdx) < 1.5);
        if (isempty(ie))
            fprintf(1, '    ***Cannot find call exit date: skipping entry on %i!\n', yyyymmddEntry(d));
            continue; % Do not enter on this event
        end
        ie=ie(end);

        %         if (isempty(isExitIdx))
        %             fprintf(1, '    ***Cannot find call exit date: skipping entry on %i!\n', yyyymmddEntry(d));
        %             continue; % Do not enter on this event
        %         end
        %
        %         ie=length(isExitIdx);
        
        %         entryPriceC=bid(isEntryIdx); % At market
        %         entryPriceC=ask(isEntryIdx); % Limit
        entryPriceC=(bid(isEntryIdx)+ask(isEntryIdx))/2; % Midpoint
        exitPriceC=bid(isExitIdx(ie));
        
        hhmmssEntry=str2double(datestr(dn(isEntryIdx), 'HHMMSS'));
        hhmmssfffEntry=datestr(dn(isEntryIdx), 'HH:MM:SS.FFF');
        
        yyyymmddExit=str2double(datestr(dn(isExitIdx(ie)), 'yyyymmdd'));
        hhmmssExit=str2double(datestr(dn(isExitIdx(ie)), 'HHMMSS'));
        hhmmssfffExit=datestr(dn(isExitIdx(ie)), 'HH:MM:SS.FFF');

        
        %% Put
        fid=fopen(['//I3/Options_data/LO.', contract, '/pLO', contract, stkPriceOTMPutStr, 'P_BBO_', dateRange, '.csv']);
        assert(fid~=-1);
                
        dn1=[];
        bid1=[];
        ask1=[];
        
        while (1)
            C=textscan(fid, '%u%s%f%f', len, 'Delimiter', ',');
            if (isempty(C))
                break;
            end
            if (length(C{1, 1})==0)
                break;
            end
            
            tday=num2str(C{1, 1});
            hhmmssfff=C{1, 2};
            
            bid1=[bid1; C{1, 3}];
            ask1=[ask1; C{1, 4}];
            
            dn1=[dn1; datenum(cellstr([tday, repmat(' ', size(hhmmssfff)), char(hhmmssfff)]), 'yyyymmdd HH:MM:SS.FFF')];
        end
        
        fclose(fid);
        
        %%%
        
        bid=NaN(size(bid1));
        ask=NaN(size(bid));
        dn=NaN(size(bid));
        
        t=1;
        t1=1;
        
        while (t1 <= length(dn1) )
            if (bid1(t1) ~= 0 && ask1(t1) ~= 0)
                bid(t, 1)=bid1(t1);
                ask(t, 1)=ask1(t1);
                dn(t)=dn1(t1);
                t=t+1;
            end
            t1=t1+1;
        end
        
        lastGoodData=find(isfinite(dn));
        lastGoodData=lastGoodData(end);
        
        dn=dn(1:lastGoodData)';
        bid=bid(1:lastGoodData, :);
        ask=ask(1:lastGoodData, :);
        
        bid=fillMissingData(bid);
        ask=fillMissingData(ask);
        
        goodData=dn >= datenum(firstDateTime, 'yyyymmdd HH:MM:SS') & dn <= datenum(lastDateTime, 'yyyymmdd HH:MM:SS');
        
        dn=dn(goodData);
        bid=bid(goodData);
        ask=ask(goodData);
                
        hhmmPut=str2double(cellstr(datestr(dn, 'HHMM')));
        yyyymmddPut=yyyymmdd(datetime(dn, 'ConvertFrom', 'datenum'))';

        isEntry=hhmmPut < entryTime & yyyymmddPut==yyyymmddEntry(d); 
        isExit=hhmmPut < exitTime & yyyymmddPut == yyyymmddExit;
        isEntryIdx=find(isEntry);
        isEntryIdx=isEntryIdx(end); % use latest entry
        isExitIdx=find(isExit);

        if (isempty(isExitIdx))
            fprintf(1, '    Missing put data on exit date %i: skipping...\n', yyyymmddExit);
            continue;
        end
        
        %         entryPriceP=bid(isEntryIdx); % At market
        %         entryPriceP=ask(isEntryIdx); % At limit
        entryPriceP=(bid(isEntryIdx)+ask(isEntryIdx))/2; % Midpoint
        exitPriceP=bid(isExitIdx(end)); % Select last tick to exit
        
        fprintf(fidout,'CL_%sC%s_FOP,%i,%s,Bought,%f,%i,0\n',    contract, padzero(stkPriceOTMCallStr), yyyymmddEntry(d), hhmmssfffEntry, entryPriceC, numLevels);
        fprintf(fidout,'CL_%sC%s_FOP,%i,%s,Sold,%f,%i,0\n',      contract, padzero(stkPriceOTMCallStr), yyyymmddExit,     hhmmssfffExit,  exitPriceC, numLevels);

        fprintf(fidout,'CL_%sP%s_FOP,%i,%s,Bought,%f,%i,0\n',   contract, padzero(stkPriceOTMPutStr), yyyymmddEntry(d), hhmmssfffEntry, entryPriceP, numLevels);
        fprintf(fidout,'CL_%sP%s_FOP,%i,%s,Sold,%f,%i,0\n',     contract, padzero(stkPriceOTMPutStr), yyyymmddExit,     hhmmssfffExit,  exitPriceP, numLevels);

        %%
        PL=PL_Fut+numLevels*((exitPriceC-entryPriceC)+(exitPriceP-entryPriceP));
        fprintf(1, '%s %s-%s: PL=%5.2f PL_Fut=%5.2f maxLevelReached=%i\n', contract, datestr(dn(isEntryIdx), 'yyyymmdd HH:MM:SS'), datestr(dn(isExitIdx(end)), 'yyyymmdd HH:MM:SS'), PL, PL_Fut, maxLevelReached );
        cumPL=cumPL+PL;
        cumPL_Fut=cumPL_Fut+PL_Fut;
    end
    
end

fprintf(1, 'cumPL=%5.2f cumPL_Fut=%5.2f\n', cumPL, cumPL_Fut);

fclose(fidout);

% Mid-quote entry for both futures and options, MKT exit.

% numLevels=1, otm=0.01
% J12 20120301 08:59:59-20120302 14:29:58: PL= 1.30 PL_Fut= 1.50 maxLevelReached=1
% K12 20120315 08:59:35-20120316 14:29:59: PL= 0.85 PL_Fut= 1.10 maxLevelReached=1
% K12 20120322 08:59:59-20120323 14:29:59: PL= 1.23 PL_Fut= 1.32 maxLevelReached=1
% K12 20120329 08:59:58-20120330 14:29:59: PL=-1.00 PL_Fut=-0.98 maxLevelReached=1
%     ***Cannot find futures exit date: skipping entry on 20120405!
% M12 20120412 08:59:59-20120413 14:29:59: PL= 0.58 PL_Fut= 1.05 maxLevelReached=1
% M12 20120419 08:59:59-20120420 14:29:59: PL=-0.18 PL_Fut= 0.03 maxLevelReached=1
% M12 20120426 08:59:58-20120427 14:29:59: PL=-0.43 PL_Fut= 0.00 maxLevelReached=0
% M12 20120503 08:59:59-20120504 14:29:58: PL=-2.34 PL_Fut=-5.56 maxLevelReached=1
% N12 20120510 08:59:59-20120511 14:29:59: PL=-0.60 PL_Fut=-0.34 maxLevelReached=1
% N12 20120517 08:59:57-20120518 14:29:59: PL=-1.34 PL_Fut=-1.33 maxLevelReached=1
% N12 20120524 08:59:59-20120525 14:29:59: PL= 0.67 PL_Fut= 0.93 maxLevelReached=1
% N12 20120531 08:59:59-20120601 14:29:59: PL=-1.08 PL_Fut=-2.56 maxLevelReached=1
% Q12 20120614 08:59:59-20120615 14:29:58: PL=-0.43 PL_Fut=-0.27 maxLevelReached=1
% Q12 20120621 08:59:59-20120622 14:29:59: PL= 0.67 PL_Fut= 1.00 maxLevelReached=1
% Q12 20120628 08:59:59-20120629 14:29:59: PL=-1.51 PL_Fut=-2.67 maxLevelReached=1
%     ***Cannot find futures exit date: skipping entry on 20120705!
% U12 20120712 08:59:57-20120713 14:29:57: PL=-1.73 PL_Fut=-1.52 maxLevelReached=1
% U12 20120719 08:59:58-20120720 14:29:59: PL= 1.04 PL_Fut= 1.04 maxLevelReached=1
% U12 20120726 08:59:59-20120727 14:29:59: PL= 0.58 PL_Fut= 0.90 maxLevelReached=1
% U12 20120802 08:59:59-20120803 14:29:59: PL=-1.13 PL_Fut=-1.73 maxLevelReached=1
% V12 20120809 08:59:59-20120810 14:29:59: PL=-0.27 PL_Fut= 0.00 maxLevelReached=1
% V12 20120816 08:59:58-20120817 14:29:57: PL=-0.39 PL_Fut=-0.35 maxLevelReached=1
% V12 20120823 08:59:59-20120824 14:29:59: PL=-0.40 PL_Fut=-0.34 maxLevelReached=1
% V12 20120830 08:59:59-20120831 14:29:59: PL= 1.47 PL_Fut= 1.75 maxLevelReached=1
% X12 20120906 08:59:59-20120907 14:29:58: PL= 2.65 PL_Fut= 2.97 maxLevelReached=1
% X12 20120913 08:59:59-20120914 14:29:59: PL= 0.93 PL_Fut= 0.70 maxLevelReached=1
% X12 20120920 08:59:59-20120921 14:29:59: PL=-0.65 PL_Fut= 0.07 maxLevelReached=1
% X12 20120927 08:59:59-20120928 14:29:59: PL= 0.68 PL_Fut= 1.22 maxLevelReached=1
% X12 20121004 08:59:59-20121005 10:29:55: PL=-0.37 PL_Fut=-0.27 maxLevelReached=1
% Z12 20121011 08:59:59-20121012 14:29:59: PL= 0.13 PL_Fut= 0.54 maxLevelReached=1
% Z12 20121018 08:59:51-20121019 14:29:59: PL= 0.19 PL_Fut= 0.36 maxLevelReached=1
% Z12 20121025 08:59:59-20121026 14:29:59: PL= 1.34 PL_Fut= 1.76 maxLevelReached=1
% Z12 20121101 08:59:59-20121102 14:29:59: PL= 0.12 PL_Fut= 0.20 maxLevelReached=1
% F13 20121108 08:59:57-20121109 14:29:59: PL= 1.35 PL_Fut= 1.75 maxLevelReached=1
% F13 20121115 08:59:59-20121116 14:29:58: PL= 0.83 PL_Fut= 0.88 maxLevelReached=1
% F13 20121122 08:00:13-20121123 13:45:00: PL=-1.83 PL_Fut=-0.06 maxLevelReached=1
% F13 20121129 08:59:59-20121130 14:29:58: PL= 0.41 PL_Fut= 0.49 maxLevelReached=1
% G13 20121206 08:59:59-20121207 14:29:57: PL=-0.42 PL_Fut=-0.35 maxLevelReached=1
% G13 20121213 08:59:59-20121214 14:29:59: PL=-0.10 PL_Fut= 0.00 maxLevelReached=0
% G13 20121220 08:59:59-20121221 14:29:48: PL= 0.95 PL_Fut= 1.05 maxLevelReached=1
% G13 20121227 08:59:59-20121228 14:29:59: PL= 1.16 PL_Fut= 1.27 maxLevelReached=1
% G13 20130103 08:59:59-20130104 14:29:59: PL= 0.37 PL_Fut= 0.94 maxLevelReached=1
% H13 20130110 08:59:59-20130111 14:29:58: PL=-0.14 PL_Fut=-0.02 maxLevelReached=1
% H13 20130117 08:59:59-20130118 14:29:59: PL= 0.61 PL_Fut= 0.98 maxLevelReached=1
% H13 20130124 08:59:59-20130125 14:29:58: PL=-0.09 PL_Fut= 0.00 maxLevelReached=0
% H13 20130131 08:59:58-20130201 14:29:59: PL= 0.78 PL_Fut= 0.98 maxLevelReached=1
% J13 20130207 08:59:59-20130208 14:29:59: PL=-0.19 PL_Fut= 0.14 maxLevelReached=1
% J13 20130214 08:59:59-20130215 14:29:59: PL=-0.10 PL_Fut=-0.37 maxLevelReached=1
% J13 20130221 08:59:59-20130222 14:29:59: PL=-0.07 PL_Fut= 0.51 maxLevelReached=1
% cumPL= 4.08 cumPL_Fut= 8.68 maxDD=13.701

% numLevels=1; % 1 levels for CL
% levelWidth=0.01; % Each level is 1%
% 
% otm=0.02; % otm should be (1+numLevels)*levelWidth
% 
% J12 20120301 08:59:59-20120302 14:29:58: PL= 1.27 PL_Fut= 1.50 maxLevelReached=1
% K12 20120315 08:59:35-20120316 14:29:59: PL= 0.87 PL_Fut= 1.10 maxLevelReached=1
% K12 20120322 08:59:59-20120323 14:29:53: PL= 1.24 PL_Fut= 1.32 maxLevelReached=1
% K12 20120329 08:59:55-20120330 14:29:59: PL=-0.96 PL_Fut=-0.98 maxLevelReached=1
%     ***Cannot find futures exit date: skipping entry on 20120405!
% M12 20120412 08:59:58-20120413 14:29:54: PL= 0.62 PL_Fut= 1.05 maxLevelReached=1
% M12 20120419 08:59:59-20120420 14:29:57: PL=-0.18 PL_Fut= 0.03 maxLevelReached=1
% M12 20120426 08:59:58-20120427 14:29:59: PL=-0.41 PL_Fut= 0.00 maxLevelReached=0
% M12 20120503 08:59:59-20120504 14:29:59: PL=-2.53 PL_Fut=-5.56 maxLevelReached=1
% N12 20120510 08:59:59-20120511 14:29:59: PL=-0.60 PL_Fut=-0.34 maxLevelReached=1
% N12 20120517 08:59:59-20120518 14:29:59: PL=-1.34 PL_Fut=-1.33 maxLevelReached=1
% N12 20120524 08:59:59-20120525 14:29:58: PL= 0.69 PL_Fut= 0.93 maxLevelReached=1
% N12 20120531 08:59:59-20120601 14:29:58: PL=-0.91 PL_Fut=-2.56 maxLevelReached=1
% Q12 20120614 08:59:59-20120615 14:29:58: PL=-0.42 PL_Fut=-0.27 maxLevelReached=1
% Q12 20120621 08:59:59-20120622 14:29:59: PL= 0.67 PL_Fut= 1.00 maxLevelReached=1
% Q12 20120628 08:59:58-20120629 14:29:59: PL=-1.45 PL_Fut=-2.67 maxLevelReached=1
%     ***Cannot find futures exit date: skipping entry on 20120705!
% U12 20120712 08:59:59-20120713 14:29:57: PL=-1.73 PL_Fut=-1.52 maxLevelReached=1
% U12 20120719 08:59:54-20120720 14:29:59: PL= 1.01 PL_Fut= 1.04 maxLevelReached=1
% U12 20120726 08:59:59-20120727 14:29:59: PL= 0.59 PL_Fut= 0.90 maxLevelReached=1
% U12 20120802 08:59:59-20120803 14:29:58: PL=-1.04 PL_Fut=-1.73 maxLevelReached=1
% V12 20120809 08:59:59-20120810 14:29:59: PL=-0.24 PL_Fut= 0.00 maxLevelReached=1
% V12 20120816 08:59:59-20120817 14:29:59: PL=-0.39 PL_Fut=-0.35 maxLevelReached=1
% V12 20120823 08:59:59-20120824 14:29:58: PL=-0.40 PL_Fut=-0.34 maxLevelReached=1
% V12 20120830 08:59:59-20120831 14:29:59: PL= 1.52 PL_Fut= 1.75 maxLevelReached=1
% X12 20120906 08:59:59-20120907 14:29:59: PL= 2.65 PL_Fut= 2.97 maxLevelReached=1
% X12 20120913 08:59:59-20120914 14:29:59: PL= 0.95 PL_Fut= 0.70 maxLevelReached=1
% X12 20120920 08:59:59-20120921 14:29:59: PL=-0.66 PL_Fut= 0.07 maxLevelReached=1
% X12 20120927 08:59:59-20120928 14:29:59: PL= 0.68 PL_Fut= 1.22 maxLevelReached=1
% X12 20121004 08:59:59-20121005 10:29:58: PL=-0.32 PL_Fut=-0.27 maxLevelReached=1
% Z12 20121011 08:59:59-20121012 14:29:59: PL= 0.16 PL_Fut= 0.54 maxLevelReached=1
% Z12 20121018 08:59:59-20121019 14:29:58: PL= 0.21 PL_Fut= 0.36 maxLevelReached=1
% Z12 20121025 08:59:59-20121026 14:29:59: PL= 1.37 PL_Fut= 1.76 maxLevelReached=1
% Z12 20121101 08:59:59-20121102 14:29:59: PL= 0.07 PL_Fut= 0.20 maxLevelReached=1
% F13 20121108 08:59:57-20121109 14:29:59: PL= 1.36 PL_Fut= 1.75 maxLevelReached=1
% F13 20121115 08:59:59-20121116 14:29:59: PL= 0.84 PL_Fut= 0.88 maxLevelReached=1
% F13 20121122 08:59:03-20121123 13:45:00: PL=-1.47 PL_Fut=-0.06 maxLevelReached=1
% F13 20121129 08:59:59-20121130 14:29:58: PL= 0.43 PL_Fut= 0.49 maxLevelReached=1
% G13 20121206 08:59:59-20121207 14:29:59: PL=-0.40 PL_Fut=-0.35 maxLevelReached=1
% G13 20121213 08:59:59-20121214 14:29:59: PL=-0.08 PL_Fut= 0.00 maxLevelReached=0
% G13 20121220 08:59:59-20121221 14:29:38: PL= 0.95 PL_Fut= 1.05 maxLevelReached=1
% G13 20121227 08:59:59-20121228 14:29:59: PL= 1.17 PL_Fut= 1.27 maxLevelReached=1
% G13 20130103 08:59:59-20130104 14:29:59: PL= 0.44 PL_Fut= 0.94 maxLevelReached=1
% H13 20130110 08:59:59-20130111 14:29:58: PL=-0.12 PL_Fut=-0.02 maxLevelReached=1
% H13 20130117 08:59:59-20130118 14:29:59: PL= 0.61 PL_Fut= 0.98 maxLevelReached=1
% H13 20130124 08:59:59-20130125 14:29:58: PL=-0.05 PL_Fut= 0.00 maxLevelReached=0
% H13 20130131 08:59:57-20130201 14:29:59: PL= 0.80 PL_Fut= 0.98 maxLevelReached=1
% J13 20130207 08:59:59-20130208 14:29:57: PL=-0.15 PL_Fut= 0.14 maxLevelReached=1
% J13 20130214 08:59:59-20130215 14:29:59: PL=-0.07 PL_Fut=-0.37 maxLevelReached=1
% J13 20130221 08:59:59-20130222 14:29:59: PL=-0.05 PL_Fut= 0.51 maxLevelReached=1
% cumPL= 5.20 cumPL_Fut= 8.68 maxDD=-12.80

% numLevels=2; % 1 levels for CL
% levelWidth=0.01; % Each level is 1%
% 
% otm=0.03; % otm should be (1+numLevels)*levelWidth

% J12 20120301 08:59:59-20120302 14:29:56: PL= 2.19 PL_Fut= 2.58 maxLevelReached=2
% K12 20120315 08:59:33-20120316 14:29:59: PL= 1.73 PL_Fut= 2.18 maxLevelReached=2
% K12 20120322 08:59:59-20120323 14:29:53: PL= 2.24 PL_Fut= 2.39 maxLevelReached=2
% K12 20120329 08:59:56-20120330 14:29:59: PL= 0.27 PL_Fut= 0.14 maxLevelReached=2
%     ***Cannot find futures exit date: skipping entry on 20120405!
% M12 20120412 08:59:58-20120413 14:29:59: PL= 0.20 PL_Fut= 1.05 maxLevelReached=1
% M12 20120419 08:59:59-20120420 14:29:59: PL=-0.33 PL_Fut= 0.03 maxLevelReached=1
% M12 20120426 08:59:58-20120427 14:29:59: PL=-0.78 PL_Fut= 0.00 maxLevelReached=0
% M12 20120503 08:59:59-20120504 14:29:59: PL=-4.53 PL_Fut=-10.02 maxLevelReached=2
% N12 20120510 08:59:59-20120511 14:29:58: PL=-0.77 PL_Fut=-0.34 maxLevelReached=1
% N12 20120517 08:59:59-20120518 14:29:59: PL=-0.55 PL_Fut=-0.72 maxLevelReached=2
% N12 20120524 08:59:59-20120525 14:29:58: PL= 0.44 PL_Fut= 0.93 maxLevelReached=1
% N12 20120531 08:59:59-20120601 14:29:58: PL=-2.16 PL_Fut=-5.17 maxLevelReached=2
% Q12 20120614 08:59:59-20120615 14:29:57: PL= 0.41 PL_Fut= 0.66 maxLevelReached=2
% Q12 20120621 08:59:59-20120622 14:29:59: PL= 1.26 PL_Fut= 1.84 maxLevelReached=2
% Q12 20120628 08:59:58-20120629 14:29:59: PL=-1.78 PL_Fut=-4.51 maxLevelReached=2
%     ***Cannot find futures exit date: skipping entry on 20120705!
% U12 20120712 08:59:57-20120713 14:29:58: PL=-2.46 PL_Fut=-2.19 maxLevelReached=2
% U12 20120719 08:59:54-20120720 14:29:59: PL= 1.93 PL_Fut= 1.96 maxLevelReached=2
% U12 20120726 08:59:59-20120727 14:29:59: PL= 0.32 PL_Fut= 0.90 maxLevelReached=1
% U12 20120802 08:59:59-20120803 14:29:58: PL=-2.40 PL_Fut=-3.48 maxLevelReached=2
% V12 20120809 08:59:58-20120810 14:29:59: PL= 0.52 PL_Fut= 0.96 maxLevelReached=2
% V12 20120816 08:59:54-20120817 14:29:55: PL=-0.46 PL_Fut=-0.35 maxLevelReached=1
% V12 20120823 08:59:59-20120824 14:29:59: PL= 0.54 PL_Fut= 0.64 maxLevelReached=2
% V12 20120830 08:59:59-20120831 14:29:59: PL= 1.30 PL_Fut= 1.75 maxLevelReached=1
% X12 20120906 08:59:59-20120907 14:29:58: PL= 2.30 PL_Fut= 2.97 maxLevelReached=1
% X12 20120913 08:59:59-20120914 14:29:59: PL= 2.18 PL_Fut= 1.69 maxLevelReached=2
% X12 20120920 08:59:59-20120921 14:29:59: PL=-1.40 PL_Fut= 0.07 maxLevelReached=1
% X12 20120927 08:59:59-20120928 14:29:56: PL= 0.17 PL_Fut= 1.22 maxLevelReached=1
% X12 20121004 08:59:59-20121005 10:29:55: PL= 0.15 PL_Fut= 0.34 maxLevelReached=2
% Z12 20121011 08:59:59-20121012 14:29:59: PL=-0.17 PL_Fut= 0.54 maxLevelReached=1
% Z12 20121018 08:59:58-20121019 14:29:59: PL= 0.06 PL_Fut= 0.36 maxLevelReached=1
% Z12 20121025 08:59:59-20121026 14:29:59: PL= 1.07 PL_Fut= 1.76 maxLevelReached=1
% Z12 20121101 08:59:59-20121102 14:29:59: PL= 0.17 PL_Fut= 0.20 maxLevelReached=1
% F13 20121108 08:59:59-20121109 14:29:59: PL= 0.96 PL_Fut= 1.75 maxLevelReached=1
% F13 20121115 08:59:59-20121116 14:29:58: PL= 1.67 PL_Fut= 1.76 maxLevelReached=2
% F13 20121122 08:59:14-20121123 13:44:37: PL=-0.61 PL_Fut=-0.06 maxLevelReached=1
% F13 20121129 08:59:59-20121130 14:29:58: PL= 0.42 PL_Fut= 0.49 maxLevelReached=1
% G13 20121206 08:59:59-20121207 14:29:58: PL=-0.48 PL_Fut=-0.35 maxLevelReached=1
% G13 20121213 08:59:57-20121214 14:29:59: PL=-0.16 PL_Fut= 0.00 maxLevelReached=0
% G13 20121220 08:59:59-20121221 14:29:48: PL= 0.90 PL_Fut= 1.05 maxLevelReached=1
% G13 20121227 08:59:59-20121228 14:29:59: PL= 1.10 PL_Fut= 1.27 maxLevelReached=1
% G13 20130103 08:59:59-20130104 14:29:59: PL= 0.07 PL_Fut= 0.94 maxLevelReached=1
% H13 20130110 08:59:59-20130111 14:29:58: PL= 0.78 PL_Fut= 0.91 maxLevelReached=2
% H13 20130117 08:59:59-20130118 14:29:59: PL= 0.29 PL_Fut= 0.98 maxLevelReached=1
% H13 20130124 08:59:59-20130125 14:29:58: PL=-0.08 PL_Fut= 0.00 maxLevelReached=0
% H13 20130131 08:59:59-20130201 14:29:59: PL= 0.66 PL_Fut= 0.98 maxLevelReached=1
% J13 20130207 08:59:50-20130208 14:29:57: PL=-0.37 PL_Fut= 0.14 maxLevelReached=1
% J13 20130214 08:59:59-20130215 14:29:59: PL= 0.74 PL_Fut= 0.23 maxLevelReached=2
% J13 20130221 08:59:59-20130222 14:29:59: PL=-0.46 PL_Fut= 0.51 maxLevelReached=1
% cumPL= 7.08 cumPL_Fut=10.97 maxDD=-20.14

% numLevels=3; % 1 levels for CL
% levelWidth=0.01; % Each level is 1%
% 
% otm=0.04; % otm should be (1+numLevels)*levelWidth

% J12 20120301 08:59:59-20120302 14:29:59: PL= 2.06 PL_Fut= 2.58 maxLevelReached=2
% K12 20120315 08:59:31-20120316 14:29:59: PL= 1.58 PL_Fut= 2.18 maxLevelReached=2
% K12 20120322 08:59:58-20120323 14:29:59: PL= 2.14 PL_Fut= 2.39 maxLevelReached=2
% K12 20120329 08:59:55-20120330 14:29:59: PL= 0.53 PL_Fut= 0.14 maxLevelReached=2
%     ***Cannot find futures exit date: skipping entry on 20120405!
% M12 20120412 08:59:58-20120413 14:29:59: PL=-0.14 PL_Fut= 1.05 maxLevelReached=1
% M12 20120419 08:59:59-20120420 14:29:57: PL=-0.48 PL_Fut= 0.03 maxLevelReached=1
% M12 20120426 08:59:58-20120427 14:29:59: PL=-1.08 PL_Fut= 0.00 maxLevelReached=0
% M12 20120503 08:59:59-20120504 14:29:59: PL=-6.04 PL_Fut=-13.48 maxLevelReached=3
% N12 20120510 08:59:59-20120511 14:29:59: PL=-0.87 PL_Fut=-0.34 maxLevelReached=1
% N12 20120517 08:59:59-20120518 14:29:59: PL=-0.32 PL_Fut=-0.72 maxLevelReached=2
% N12 20120524 08:59:59-20120525 14:29:51: PL= 0.30 PL_Fut= 0.93 maxLevelReached=1
% N12 20120531 08:59:59-20120601 14:29:58: PL=-2.58 PL_Fut=-6.89 maxLevelReached=3
% Q12 20120614 08:59:59-20120615 14:29:50: PL= 0.16 PL_Fut= 0.66 maxLevelReached=2
% Q12 20120621 08:59:59-20120622 14:29:59: PL= 1.75 PL_Fut= 2.67 maxLevelReached=3
% Q12 20120628 08:59:59-20120629 14:29:59: PL=-2.07 PL_Fut=-5.53 maxLevelReached=3
%     ***Cannot find futures exit date: skipping entry on 20120705!
% U12 20120712 08:59:59-20120713 14:29:57: PL=-2.54 PL_Fut=-2.00 maxLevelReached=3
% U12 20120719 08:59:54-20120720 14:29:59: PL= 1.96 PL_Fut= 1.96 maxLevelReached=2
% U12 20120726 08:59:59-20120727 14:29:59: PL= 0.08 PL_Fut= 0.90 maxLevelReached=1
% U12 20120802 08:59:59-20120803 14:29:57: PL=-2.88 PL_Fut=-4.35 maxLevelReached=3
% V12 20120809 08:59:58-20120810 14:29:59: PL= 0.31 PL_Fut= 0.96 maxLevelReached=2
% V12 20120816 08:59:59-20120817 14:29:55: PL=-0.55 PL_Fut=-0.35 maxLevelReached=1
% V12 20120823 08:59:59-20120824 14:29:59: PL= 0.49 PL_Fut= 0.64 maxLevelReached=2
% V12 20120830 08:59:59-20120831 14:29:59: PL= 1.09 PL_Fut= 1.75 maxLevelReached=1
% X12 20120906 08:59:59-20120907 14:29:58: PL= 2.01 PL_Fut= 2.97 maxLevelReached=1
% X12 20120913 08:59:59-20120914 14:29:59: PL= 2.39 PL_Fut= 1.69 maxLevelReached=2
% X12 20120920 08:59:59-20120921 14:29:59: PL=-2.03 PL_Fut= 0.07 maxLevelReached=1
% X12 20120927 08:59:59-20120928 14:29:56: PL=-0.25 PL_Fut= 1.22 maxLevelReached=1
% X12 20121004 08:59:59-20121005 10:29:58: PL= 1.86 PL_Fut= 2.19 maxLevelReached=3
% Z12 20121011 08:59:59-20121012 14:29:58: PL=-0.46 PL_Fut= 0.54 maxLevelReached=1
% Z12 20121018 08:59:57-20121019 14:29:59: PL=-0.03 PL_Fut= 0.36 maxLevelReached=1
% Z12 20121025 08:59:59-20121026 14:29:59: PL= 0.76 PL_Fut= 1.76 maxLevelReached=1
% Z12 20121101 08:59:59-20121102 14:29:59: PL= 0.20 PL_Fut= 0.20 maxLevelReached=1
% F13 20121108 08:59:59-20121109 14:29:59: PL= 0.64 PL_Fut= 1.75 maxLevelReached=1
% F13 20121115 08:59:59-20121116 14:29:59: PL= 1.64 PL_Fut= 1.76 maxLevelReached=2
% F13 20121122 08:00:13-20121123 13:45:00: PL=-3.00 PL_Fut=-0.06 maxLevelReached=1
% F13 20121129 08:59:59-20121130 14:29:56: PL= 0.50 PL_Fut= 0.49 maxLevelReached=1
% G13 20121206 08:59:59-20121207 14:29:59: PL=-0.59 PL_Fut=-0.35 maxLevelReached=1
% G13 20121213 08:59:59-20121214 14:29:59: PL=-0.24 PL_Fut= 0.00 maxLevelReached=0
% G13 20121220 08:59:59-20121221 14:29:59: PL= 0.85 PL_Fut= 1.05 maxLevelReached=1
% G13 20121227 08:59:59-20121228 14:29:59: PL= 1.09 PL_Fut= 1.27 maxLevelReached=1
% G13 20130103 08:59:59-20130104 14:29:57: PL=-0.11 PL_Fut= 0.94 maxLevelReached=1
% H13 20130110 08:59:59-20130111 14:29:57: PL= 0.77 PL_Fut= 0.91 maxLevelReached=2
% H13 20130117 08:59:59-20130118 14:29:59: PL= 0.02 PL_Fut= 0.98 maxLevelReached=1
% H13 20130124 08:59:59-20130125 14:29:58: PL=-0.06 PL_Fut= 0.00 maxLevelReached=0
% H13 20130131 08:59:50-20130201 14:29:59: PL= 0.61 PL_Fut= 0.98 maxLevelReached=1
% J13 20130207 08:59:59-20130208 14:29:56: PL=-0.49 PL_Fut= 0.14 maxLevelReached=1
% J13 20130214 08:59:59-20130215 14:29:59: PL= 0.94 PL_Fut= 0.23 maxLevelReached=2
% J13 20130221 08:59:59-20130222 14:29:59: PL=-0.70 PL_Fut= 0.51 maxLevelReached=1
% cumPL=-0.79 cumPL_Fut= 6.75

% numLevels=1; % 1 levels for CL
% levelWidth=0.01; % Each level is 1%
% 
% otm=0.05; % otm should be (1+numLevels)*levelWidth

% J12 20120301 08:59:59-20120302 14:29:58: PL= 1.38 PL_Fut= 1.50 maxLevelReached=1
% K12 20120315 08:59:35-20120316 14:29:58: PL= 0.89 PL_Fut= 1.10 maxLevelReached=1
% K12 20120322 08:59:59-20120323 14:29:59: PL= 1.24 PL_Fut= 1.32 maxLevelReached=1
% K12 20120329 08:59:57-20120330 14:29:59: PL=-0.87 PL_Fut=-0.98 maxLevelReached=1
%     ***Cannot find futures exit date: skipping entry on 20120405!
% M12 20120412 08:59:59-20120413 14:29:59: PL= 0.67 PL_Fut= 1.05 maxLevelReached=1
% M12 20120419 08:59:57-20120420 14:29:59: PL=-0.15 PL_Fut= 0.03 maxLevelReached=1
% M12 20120426 08:59:58-20120427 14:29:59: PL=-0.32 PL_Fut= 0.00 maxLevelReached=0
% M12 20120503 08:59:59-20120504 14:29:59: PL=-3.45 PL_Fut=-5.56 maxLevelReached=1
% N12 20120510 08:59:59-20120511 14:29:59: PL=-0.48 PL_Fut=-0.34 maxLevelReached=1
% N12 20120517 08:59:59-20120518 14:29:59: PL=-1.17 PL_Fut=-1.33 maxLevelReached=1
% N12 20120524 08:59:59-20120525 14:29:59: PL= 0.74 PL_Fut= 0.93 maxLevelReached=1
% N12 20120531 08:59:59-20120601 14:29:59: PL=-1.19 PL_Fut=-2.56 maxLevelReached=1
% Q12 20120614 08:59:59-20120615 14:29:57: PL=-0.45 PL_Fut=-0.27 maxLevelReached=1
% Q12 20120621 08:59:59-20120622 14:29:59: PL= 0.74 PL_Fut= 1.00 maxLevelReached=1
% Q12 20120628 08:59:59-20120629 14:29:59: PL=-1.71 PL_Fut=-2.67 maxLevelReached=1
%     ***Cannot find futures exit date: skipping entry on 20120705!
% U12 20120712 08:59:57-20120713 14:29:58: PL=-1.69 PL_Fut=-1.52 maxLevelReached=1
% U12 20120719 08:59:56-20120720 14:29:56: PL= 1.03 PL_Fut= 1.04 maxLevelReached=1
% U12 20120726 08:59:59-20120727 14:29:59: PL= 0.65 PL_Fut= 0.90 maxLevelReached=1
% U12 20120802 08:59:59-20120803 14:29:59: PL=-1.31 PL_Fut=-1.73 maxLevelReached=1
% V12 20120809 08:59:59-20120810 14:29:59: PL=-0.18 PL_Fut= 0.00 maxLevelReached=1
% V12 20120816 08:59:58-20120817 14:29:55: PL=-0.46 PL_Fut=-0.35 maxLevelReached=1
% V12 20120823 08:59:59-20120824 14:29:58: PL=-0.40 PL_Fut=-0.34 maxLevelReached=1
% V12 20120830 08:59:59-20120831 14:29:59: PL= 1.56 PL_Fut= 1.75 maxLevelReached=1
% X12 20120906 08:59:59-20120907 14:29:58: PL= 2.65 PL_Fut= 2.97 maxLevelReached=1
% X12 20120913 08:59:40-20120914 14:29:48: PL= 0.93 PL_Fut= 0.70 maxLevelReached=1
% X12 20120920 08:59:59-20120921 14:29:59: PL=-0.60 PL_Fut= 0.07 maxLevelReached=1
% X12 20120927 08:59:59-20120928 14:29:59: PL= 0.77 PL_Fut= 1.22 maxLevelReached=1
% X12 20121004 08:59:59-20121005 10:29:55: PL=-0.38 PL_Fut=-0.27 maxLevelReached=1
% Z12 20121011 08:59:59-20121012 14:29:59: PL= 0.24 PL_Fut= 0.54 maxLevelReached=1
% Z12 20121018 08:59:59-20121019 14:29:58: PL= 0.26 PL_Fut= 0.36 maxLevelReached=1
% Z12 20121025 08:59:59-20121026 14:29:59: PL= 1.48 PL_Fut= 1.76 maxLevelReached=1
% Z12 20121101 08:59:16-20121102 14:29:59: PL= 0.21 PL_Fut= 0.20 maxLevelReached=1
% F13 20121108 08:59:59-20121109 14:29:59: PL= 1.38 PL_Fut= 1.75 maxLevelReached=1
% F13 20121115 08:59:59-20121116 14:29:59: PL= 0.82 PL_Fut= 0.88 maxLevelReached=1
% F13 20121122 08:58:41-20121123 13:44:42: PL=-0.77 PL_Fut=-0.06 maxLevelReached=1
% F13 20121129 08:59:59-20121130 14:29:54: PL= 0.46 PL_Fut= 0.49 maxLevelReached=1
% G13 20121206 08:59:54-20121207 14:29:57: PL=-0.40 PL_Fut=-0.35 maxLevelReached=1
% G13 20121213 08:59:59-20121214 14:29:59: PL=-0.06 PL_Fut= 0.00 maxLevelReached=0
% G13 20121220 08:59:59-20121221 14:29:59: PL= 1.00 PL_Fut= 1.05 maxLevelReached=1
% G13 20121227 08:59:59-20121228 14:29:59: PL= 1.22 PL_Fut= 1.27 maxLevelReached=1
% G13 20130103 08:59:59-20130104 14:29:52: PL= 0.68 PL_Fut= 0.94 maxLevelReached=1
% H13 20130110 08:59:59-20130111 14:29:58: PL=-0.06 PL_Fut=-0.02 maxLevelReached=1
% H13 20130117 08:59:59-20130118 14:29:59: PL= 0.70 PL_Fut= 0.98 maxLevelReached=1
% H13 20130124 08:59:52-20130125 14:29:58: PL=-0.01 PL_Fut= 0.00 maxLevelReached=0
% H13 20130131 08:59:57-20130201 14:29:59: PL= 0.87 PL_Fut= 0.98 maxLevelReached=1
% J13 20130207 08:59:59-20130208 14:29:56: PL=-0.01 PL_Fut= 0.14 maxLevelReached=1
% J13 20130214 08:59:59-20130215 14:29:59: PL=-0.18 PL_Fut=-0.37 maxLevelReached=1
% J13 20130221 08:59:59-20130222 14:29:57: PL= 0.14 PL_Fut= 0.51 maxLevelReached=1
% cumPL= 6.37 cumPL_Fut= 8.68 maxDD=-9.4