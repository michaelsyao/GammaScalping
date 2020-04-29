%Strategy 1: ShortStrangle for Futures
% Short at Thursday 9:00, exit at next Tues 16:29 to avoid the API weekly bulletin and the EIA weekly petroleum status report.
clear;

entryDay=5; % Thurs
exitDay=3; % Tues
entryTime=900;
exitTime=1629;
otm=0.05; % Buy 5% OTM put and call as hedge

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
    '20120809_20120810  ', ...
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

cumPL=0;
for c=1:length(contracts)
    contract=contracts{c};
    dateRange=dateRanges{c};
    firstDateTime=firstDateTimes{c};
    lastDateTime=lastDateTimes{c};
        
    % Get futures price to determine what strike price is ATM
    load(['inputData_CL', contract, '_BBO_', dateRange, '.mat'], 'dn', 'bid', 'ask');
    
    goodData=dn >= datenum(firstDateTime, 'yyyymmdd HH:MM:SS') & dn <= datenum(lastDateTime, 'yyyymmdd HH:MM:SS');
    
    dnFut=dn(goodData);
    bidFut=bid(goodData);
    askFut=ask(goodData);
    
    clear dn bid ask;
    
    midFut=(bidFut+askFut)/2;
    
    len=1000000;
        
    hhmm=str2double(cellstr(datestr(dnFut, 'HHMM')));
    
    isEntryFut=hhmm < entryTime & fwdshift(1, hhmm) >= entryTime & weekday(dnFut')==entryDay;
    
    opn=midFut(isEntryFut);
    yyyymmddFut=yyyymmdd(datetime(dnFut, 'ConvertFrom', 'datenum'));
    yyyymmddEntry=yyyymmddFut(isEntryFut);
    
    isEntryFutIdx=find(isEntryFut);
    
    roundPrice=@(x) round(2*x)/2; % =1/minPriceIncr
    
    % Iterate through each event date
    for d=1:length(opn)
               
        %         stkPriceStr=num2str(roundPrice(opn(d)));
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
        fid=fopen(['pLO', contract, stkPriceOTMCallStr, 'C_BBO_', dateRange, '.csv']);
        if (fid==-1)
            fprintf(1, '   Missing call strike price at %s on %i: skipping.\n', stkPriceOTMCallStr, yyyymmddEntry(d));
            continue;
        end
        
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

        isExit=hhmmCall < exitTime & yyyymmddCall > yyyymmddEntry(d);
        isEntryIdx=find(isEntry);
        isEntryIdx=isEntryIdx(end); % use latest entry 
        isExitIdx=find(isExit);
                     
        % Confirm futures dates are same as entry dates for options
        assert(yyyymmddEntry(d)==str2double(datestr(dn(isEntryIdx), 'yyyymmdd')));
        
        % Pick farthest exit date that is within a calendar week but more
        % than 3 calendar days
        ie=find(dn(isExitIdx)-dn(isEntryIdx) > 3 & dn(isExitIdx)-dn(isEntryIdx) < 5.5);
        if (isempty(ie))
            fprintf(1, '    ***Cannot find call exit date: skipping entry on %i!\n', yyyymmddEntry(d));
            continue; % Do not enter on this event
        end
        ie=ie(end); 

        entryPriceC=(bid(isEntryIdx)+ask(isEntryIdx))/2;
        exitPriceC=ask(isExitIdx(ie));
                hhmmssEntry=str2double(datestr(dn(isEntryIdx), 'HHMMSS'));
        
        yyyymmddExit=str2double(datestr(dn(isExitIdx(ie)), 'yyyymmdd'));
        hhmmssExit=str2double(datestr(dn(isExitIdx(ie)), 'HHMMSS'));

        %% Put
        fid=fopen(['pLO', contract, stkPriceOTMPutStr, 'P_BBO_', dateRange, '.csv']);
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

        entryPriceP=(bid(isEntryIdx)+ask(isEntryIdx))/2; 
        exitPriceP=ask(isExitIdx(end)); % Select last tick to exit
                  
        %%
        PL=-(exitPriceC-entryPriceC)-(exitPriceP-entryPriceP);
        fprintf(1, '%s-%s: PL=%5.2f\n', datestr(dn(isEntryIdx), 'yyyymmdd HH:MM:SS'), datestr(dn(isExitIdx(end)), 'yyyymmdd HH:MM:SS'), PL);
        cumPL=cumPL+PL;
    end
    
end

fprintf(1, 'cumPL=%5.2f\n', cumPL);

% All PL are based on mid-quote entry, MKT exit.

% Exit on Tuesday 16:29
% 20120301 08:59:59-20120305 10:29:59: PL= 0.14
% 20120315 08:59:35-20120320 16:28:39: PL= 0.41
% 20120322 08:59:59-20120327 16:27:45: PL= 0.48
% 20120329 08:59:57-20120403 16:26:55: PL= 0.43
%     ***Cannot find call exit date: skipping entry on 20120405!
% 20120412 08:59:59-20120417 16:23:07: PL= 0.73
% 20120419 08:59:57-20120424 16:28:10: PL= 0.60
% 20120426 08:59:58-20120501 16:27:26: PL= 0.28
%     ***Cannot find call exit date: skipping entry on 20120503!
% 20120510 08:59:59-20120515 16:28:53: PL=-0.63
% 20120517 08:59:59-20120522 16:28:30: PL= 0.53
% 20120524 08:59:59-20120529 16:28:00: PL= 0.45
% 20120531 08:59:59-20120605 10:29:55: PL=-0.22
% 20120614 08:59:59-20120619 16:28:41: PL= 0.95
% 20120621 08:59:59-20120626 16:27:06: PL= 0.71
% 20120628 08:59:59-20120703 16:13:41: PL=-2.60
%     ***Cannot find call exit date: skipping entry on 20120705!
% 20120712 08:59:57-20120717 16:28:53: PL=-0.35
% 20120719 08:59:56-20120724 16:27:37: PL= 0.21
% 20120726 08:59:59-20120731 16:28:53: PL= 0.08
%     ***Cannot find call exit date: skipping entry on 20120802!
% 20120809 08:59:59-20120814 16:27:17: PL= 0.45
% 20120816 08:59:58-20120821 16:28:52: PL= 0.30
% 20120823 08:59:59-20120828 16:28:56: PL= 0.28
% 20120830 08:59:59-20120904 16:28:19: PL= 0.28
% 20120906 08:59:59-20120911 16:28:34: PL= 0.68
% 20120913 08:59:40-20120918 16:28:52: PL=-0.20
% 20120920 08:59:59-20120925 16:28:55: PL= 0.83
% 20120927 08:59:59-20121002 16:28:28: PL= 0.73
%     ***Cannot find call exit date: skipping entry on 20121004!
% 20121011 08:59:59-20121016 16:28:01: PL= 0.60
% 20121018 08:59:59-20121023 16:28:42: PL=-1.06
% 20121025 08:59:59-20121030 16:28:57: PL= 0.34
% 20121101 08:59:16-20121105 10:30:00: PL= 0.19
% 20121108 08:59:59-20121113 16:27:49: PL= 0.46
% 20121115 08:59:59-20121120 16:28:42: PL= 0.58
% 20121122 08:58:41-20121127 16:28:59: PL= 0.48
% 20121129 08:59:59-20121204 16:27:54: PL= 0.34
% 20121206 08:59:54-20121211 16:28:55: PL= 0.32
% 20121213 08:59:59-20121218 16:28:55: PL= 0.24
% 20121220 08:59:59-20121224 13:45:00: PL=-0.06
% 20121227 08:59:59-20121231 16:28:53: PL= 0.24
%     ***Cannot find call exit date: skipping entry on 20130103!
% 20130110 08:59:59-20130115 16:28:41: PL=-0.03
% 20130117 08:59:59-20130122 16:28:58: PL= 0.42
% 20130124 08:59:52-20130129 16:23:32: PL= 0.12
% 20130131 08:59:57-20130205 10:29:56: PL= 0.10
% 20130207 08:59:59-20130212 16:28:23: PL= 0.54
% 20130214 08:59:59-20130219 16:27:59: PL=-0.01
% 20130221 08:59:59-20130226 16:28:51: PL= 0.38
% cumPL= 9.75