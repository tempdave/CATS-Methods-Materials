function makeMovieTimes(dur,timestamps,simpleread,folder,ripAudio,timewarn,whaleID,vidNums,audioonly)
dbstop if error;
% timestamps- signals whether to read embedded timestamps on the video or
% just read the encoded timestamps (i.e. if timestamps do not exist )
% folder - optional.  Can set a default folder to select a tag guide or check for videos.
% ripAudio - optional.  Default is true.  Rips the audio from video files
% into a separate folder (AudioData).  Set to false if you've already done
% this and just want to get the video time stamps (e.g. if the process got
% interupted and needed to be restarted).
% vidNums - optional.  if not present, looks at all videos.  If it is
% present, look for an existing movieTimes file and fill in the videos listed in "vidnums"
% audioonly- optional, reads audio start times from wav files and converts
% to audio data if no videos exist

if nargin<6 || isempty(timewarn); timewarn = 0.1; end
if nargin<5 || isempty(ripAudio); ripAudio = true; end
if nargin<4 || isempty(folder);  folder = 'E:\CATS\'; end
if nargin<3 || isempty(simpleread); simpleread = true; end
if nargin<2 || isempty(timestamps); timestamps = true; end
if nargin<1 || isempty(dur); dur = 15; end
if ~exist('audioonly','var') || isempty(audioonly); audioonly = false; end

cf = pwd; try cd(folder); catch; end
[movies,movieloc] = uigetfile('*.*','select FIRST movie (or audio) file from deployment','multiselect','off');
cd(movieloc);
[datafile,dataloc] = uigetfile('*.*','select .bin, .txt or .ubx file (just for the name)','multiselect','off');
cd(cf);
if ischar(movies); movies = {movies}; end

if ~exist('whaleID','var') || isempty(whaleID);
    whaleID = [];
    slashes = union(regexp(movieloc,'\'),regexp(movieloc,'/'));
    for i = 1:length(slashes)
        try
            if strcmp(movieloc(slashes(i)+9),'-')
                datenum(movieloc(slashes(i)+3:slashes(i)+8),'yymmdd');
                whaleID = movieloc(slashes(i)+1:min(slashes(i)+11,slashes(i+1)-1));
            end
        catch
            continue
        end
    end
end
%
disp(['ID = ' whaleID]);
% grab the movie files from the directory
m2 = dir(movieloc); m2 = {m2.name}; todel = false(size(m2)); todel(1:2) = true; for i = 3:length(m2); if length(m2{i})<=3 || ~(strcmp(m2{i}(end-2:end),'raw')||(strcmp(m2{i}(end-2:end),'wav')&&audioonly)||strcmpi(m2{i}(end-2:end),'mov')||strcmpi(m2{i}(end-2:end),'mp4')); todel(i) = true; end; end; m2(todel) = [];
% these try catch help choose which files to import
try % find all movies in the water to get all relevant audio
    m2times = nan(size(m2));
    for i = 1:length(m2); m2times(i) = datenum(m2{i}(min(regexp(m2{i},'-'))+1:max(regexp(m2{i},'-'))-1),'yyyymmdd-HHMMSS'); end
    rootDIR = folder; loc1 = strfind(movieloc,'CATS'); if ~isempty(loc1); rootDIR = movieloc(1:loc1+4); end
    try [~,~,txt] = xlsread([rootDIR 'TAG GUIDE.xlsx']); catch; [filename, fileloc] = uigetfile('*.xls*','Get Tag Guide to find tag off and recovery times'); [~,~,txt] = xlsread([fileloc filename]); end
    rows = find(~cellfun(@isempty, cellfun(@(x) strfind(x,whaleID),txt(:,1),'uniformoutput',false)));
    if isempty(rows); error('Could not find whaleID in TAG GUIDE'); end
    if length(rows)>1; let = input('letter of interest? (1 = a, 2 = b, 3 = c, etc.) '); lets = 'abcdefghijklmnopqrstuvwxyz'; whaleID = [whaleID lets(let)]; rows = find(~cellfun(@isempty, cellfun(@(x) strfind(x,whaleID),txt(:,1),'uniformoutput',false))); end
    col = find(~cellfun(@isempty,cellfun(@(x) strfind(x,'Recover_Time'),txt(3,:),'uniformoutput',false)));
    RecTime = max(datenum(txt(rows,col)));
    m1 = find(cellfun(@(x) strcmp(x,movies{1}), m2));
    mlast = find(m2times<RecTime,1,'last');
    movies = m2(m1:mlast); 
    disp(['Got last audio file from Tag Recovery Time, last file in water is ' movies{end}]);
catch
    cd(movieloc);
    [mlast,movieloc] = uigetfile('*.*','No recovery time in Tag Guide, select last movie or audio before recovery (to get all wav files)','multiselect','off');
    m1 = find(cellfun(@(x) strcmpi(x,movies{1}), m2));
    mlast = find(cellfun(@(x) strcmpi(x,mlast), m2));
    movies = m2(m1:mlast);
    disp(['last file selected in water is ' movies{end}]);
end

try % find all movies on whale to get frameTimes
    m2times = nan(size(m2));
    for i = 1:length(m2); m2times(i) = datenum(m2{i}(min(regexp(m2{i},'-'))+1:max(regexp(m2{i},'-'))-1),'yyyymmdd-HHMMSS'); end
    rootDIR = strfind(movieloc,'CATS'); rootDIR = movieloc(1:rootDIR+4);
    try [~,~,txt] = xlsread([rootDIR 'TAG GUIDE.xlsx']); catch; try [~,~,txt] = xlsread([fileloc filename]); catch; cd(fileloc); [filename, fileloc] = uigetfile('*.xls*','Get Tag Guide to find tag off and recovery times'); [~,~,txt] = xlsread([fileloc filename]); end; end
    rows = find(~cellfun(@isempty, cellfun(@(x) strfind(x,whaleID),txt(:,1),'uniformoutput',false)));
    col = find(~cellfun(@isempty,cellfun(@(x) strfind(x,'Tag_Off'),txt(3,:),'uniformoutput',false)));
    RecTime = max(datenum(txt(rows,col)));
    mlast = find(m2times<RecTime,1,'last');
    LastOnMovie = m2{mlast};    
    disp(['Got last movie file from Tag Off time, last file on whale is ' LastOnMovie]);
catch
    cd(movieloc);
    [mlast,movieloc] = uigetfile('*.*','No tag off time in Tag Guide, select last MOVIE before tag fell off whale (to get movie times)','multiselect','off');
    mlast = find(cellfun(@(x) strcmp(x,mlast), m2));
    LastOnMovie = m2{mlast};
    disp(['last file selected on whale is ' LastOnMovie]);
end

% this is CATS specific, read the video numbers off the video names
movN = nan(size(movies));
for n = 1:length(movies)
    lastnum = regexpi(movies{n},'.mp4');
    if isempty(lastnum); lastnum = regexpi(movies{n},'.mov'); end
    if isempty(lastnum); lastnum = regexpi(movies{n},'.raw'); end
     if isempty(lastnum)&&audioonly; lastnum = regexpi(movies{n},'.wav'); end
    movN(n) = str2num(movies{n}(lastnum-3:lastnum-1));
%     else audN(n) = str2num(movies{n}(lastnum-3:lastnum-1));
%     end
end
mfirst = movN(1);


% One version of CATS video files did not have video numbers (only times).  This adds them in. (Should be unnecessary now).
if any(diff(movN)<1) || any (diff(movN)>40)
    rename = input('Rename files to include video numbers? (Y or N) ','s');
    if regexpi(rename,'y')
        D = dir([movieloc '*.mp4']); % get the total lengths of the other files as well as the stored file time
        if isempty(D); D = dir([movieloc '*.mov']); end
        vidNam = cellstr(vertcat(D.name));
        for n = 1:length(vidNam)
            VN = [vidNam{n}(1:end-4) '-' sprintf('%08.f',n) vidNam{n}(end-3:end)];
           copyfile([movieloc vidNam{n}],[movieloc VN]);
           delete([movieloc vidNam{n}]);
           vidNam{n} = VN;
        end
        for n = 1:length(movies)
            movies{n} = vidNam{~cellfun(@isempty,cellfun(@(x) strfind(x,movies{n}(1:end-4),vidNam),'uniformoutput',false))};
            lastnum = regexpi(movies{n},'.mp4');
            if isempty(lastnum); lastnum = regexpi(movies{n},'.mov'); end
            movN(n) = str2num(movies{n}(lastnum-3:lastnum-1));
        end
    end
end

frameTimes = cell(max(movN),1);
vidDurs = nan(size(frameTimes));
if strcmp(dataloc(end-3:end-1),'raw'); dataloc = dataloc(1:end-4); end
DIR = [dataloc 'AudioData\'];
if ~exist (DIR,'dir')
    mkdir (DIR);
end

if timestamps; oframeTimes = frameTimes; end

warning('off','all');
%
if  ripAudio %gettagnum(datafile) == 45 || gettagnum(datafile) >= 48 
    % see if there are any wavfiles
    [D,F] = subdir(dataloc);
    wavfiles = cell(0,1);
    wavstr = wavfiles;
    D1 = dir(dataloc); id = [D1.isdir]; D1 = {D1.name}'; D1 = D1(~id);
    for i = 1:length(D1); D1{i} = [movieloc D1{i}]; end
    disp('Reading audio files from .raw and wav files: ');
    for i = 1:length(D); for j = 1:length(F{i}); D1{end+1} = [D{i} '\' F{i}{j}]; if strcmp(F{i}{j}(end-3:end),'.wav'); wavfiles{end+1} = F{i}{j}; wavstr{end+1} = D1{end}; disp(wavstr{end}); end; end; end
    for i = 1:length(movies); if strcmp(movies{i}(end-2:end),'raw'); disp([movieloc movies{i}]); end; end
    readaudiofiles2;
    disp(['Check that audio files were successfully written, then if you''re sure, you can delete files after ' LastOnMovie]);
    disp('Any premade wav files were moved to AudioData directory');
else
    disp('no audio was extracted from vids');
end
warning('on','all');
%
D = dir([movieloc '*.mp4']); % get the total lengths of the other files as well as the stored file time
if isempty(D); D = dir([movieloc '*.mov']); end
if isempty(D) && audioonly; D = dir([movieloc '*.wav']); end
% some other code if you need to restrict what movies it finds
% todel = [];
% for i = 1:length(D); if length(D(i).name) ~= 10; todel = [todel; i]; end; end % in case you've made any SxS files already or something silly
% D(todel) = [];
% D2 = dir([movieloc 'CATS*.mp4']);  todel = [];
% for i = 1:length(D2); if length(D2(i).name) ~= 12; todel = [todel; i]; end; end % in case you've made any SxS files already or something silly
% D2(todel) = [];
% D = [D; D2]; % new 2ks have longer file names and start with CATS
vidDN = vertcat(D.datenum); vidDN = vidDN - floor(vidDN(1)); % dates don't match, just worry about the time (but this way keeps track of if the video goes to the next day)


k = 1; vidNam = {}; vidNum = [];
for i = 1:length(movies)
    if ~strcmp(movies{i}(end-2:end),'raw') && ~strcmp(movies{i}(end-2:end),'wav')
        vid = mmread([movieloc movies{i}],[1 10]); % just read a few frames to get the total duration
        if isnan(vidDurs(movN(i)))
            vidDurs(movN(i)) = vid.totalDuration;
        end
        vidNam(k,1) = movies(i); 
        vidNum(k,1) = str2num(vidNam{k}(end-7:end-4)); k = k+1;
    else
        load([DIR movies{i}(1:end-4) 'audio.mat'],'totalDuration');
        vidDurs(movN(i)) = totalDuration;
        if audioonly
            vidNam(k,1) = movies(i);
            vidNum(k,1) = str2num(vidNam{k}(end-7:end-4)); k = k+1;
        end
    end
end
oi = nan(size(vidDurs));
if ~timestamps; oi(vidNum) = vidDN(ismember(cellstr(vertcat(D.name)),movies)); end
vidDN = oi;
oi = cell(size(vidDurs));
oi(vidNum) = vidNam;
vidNam = oi;

%
% frameTimes = cell(max(movN),1); oframeTimes = frameTimes;
if exist('vidNums','var') && ~isempty(vidNums) % if you signaled to only read a couple of the videos, load all the videos first
    try load([dataloc datafile(1:end-4) 'movieTimes.mat'],'frameTimes','oframeTimes','vidDN','vidDurs'); disp('existing movietimes file loaded');
    catch
        try
            load([dataloc datafile(1:end-4) 'movieTimesTEMP.mat'],'frameTimes','oframeTimes','vidDN','vidDurs');
            disp('movieTimesTEMP file loaded');
        catch
            disp('WARNING: No old frameTimes found, resulting frameTimes file will only be for indicated videos'); 
        end
    end
    for n = 1:length(vidNums)
        frameTimes{vidNums(n)} = []; oframeTimes{vidNums(n)} = [];
    end
else vidNums = movN;
end
% 
% start reading frames here:
 badvidDN = false(size(vidDN)); viddifs = zeros(size(badvidDN));
for n = 1:length(movies) 
    if isempty(intersect(movN(n),vidNums)); continue; end
    if audioonly; vidDN(movN(n)) = datenum(movies{n}(min(regexp(movies{n},'-'))+1:max(regexp(movies{n},'-'))-1),'yyyymmdd-HHMMSS-fff'); continue; end
    try vidDN(movN(n)) = datenum(movies{n}(min(regexp(movies{n},'-'))+1:max(regexp(movies{n},'-'))-1),'yyyymmdd-HHMMSS-fff');
    catch; warning(['Cannot read precise video start time from video ' num2str(movN(n)) ', will try to read video from timestamps on video, else may need to adjust manually'])
        badvidDN(movN(n)) = true;
         d = regexp(movies{n},'-');
        if ~strcmp(movies{n}(end-2:end),'raw')
            day = datenum(movies{n}(d(1)+1:d(2)-1),'yyyymmdd');
            starttime = 0; endtime = dur; videoL = dur+1; DAY = 0; badmovie = false;
            readwirelessvideo2;
            oi = checkbadframes(vid.times);
            if any(diff(oi)<0 | diff(oi)>2.5*median(diff(oi))); dur0 = dur; dur = round(dur/3); readwirelessvideo2; oi = checkbadframes(vid.times); dur = dur0; end
            if ~any(diff(oi)<0 | diff(oi)>2.5*median(diff(oi)));
                vidDN(movN(n)) = day + vid.times(1);
                disp(['Video ' num2str(movN(n)) ' calculated to start at ' datestr(vidDN(movN(n)),'yyyy-mmm-dd HH:MM:SS.fff')]);
                badvidDN(movN(n)) = false;
            end
        else
            try vidDN(movN(n)) = datenum(movies{n}(d(1)+1:d(3)-1),'yyyymmdd-HHMMSS');
            disp(['Audio file ' num2str(movN(n)) ' start time could only be read to the nearest second: ' datestr(vidDN(movN(n)))]);
            badvidDN(movN(n)) = false;
            catch; warning('Could not read audio time stamp');
            end
        end
    end
    if strcmp(movies{n}(end-2:end),'raw') || n > mlast;
        vidNam{movN(n)} = movies{n};
       if movN(n)>movN(mlast); vidNam{movN(n)} = []; vidDurs(movN(n)) = nan; end
       continue; 
    end
    starttime = 0;
    endtime = dur;
    videoL = dur+1;
    DAY = 0;
    badmovie = false;
    while endtime<=videoL+dur;
        clear M vid aud;
        if ~timestamps
            [vid,aud] = mmreadFT([movieloc movies{n}], [],[starttime endtime],false,true); %FT saves some time, but still not as efficient as it should be since it reads the video and not just the time
        elseif ~simpleread
            readwirelessvideo2; 
            if badmovie; if ~exist([movieloc 'bad movies\'], 'dir'); mkdir([movieloc 'bad movies\']); end
                movefile([movieloc movies{n}], [movieloc 'bad movies\' movies{n}]);
                frameTimes{vidNum(n)} = []; oframeTimes{vidNum(n)} = []; vidDN(vidNum(n)) = nan;
            end
        else %simpleread and timestamps, all simple read where
            vid = mmread([movieloc movies{n}], [],[starttime endtime],false,true);
            flag = true; iii = -1;
            while flag && iii<100 % try 100 frames until you get a good read
                iii = iii+1;
                [newf, flag] = gettimestamp(vid.frames(end-iii).cdata,false);
            end
            if ~flag; viddif = (abs(newf*24*60*60-vid.times(end-iii)-(vidDN(movN(n))-floor(vidDN(movN(n))))*24*60*60)); else viddif = nan; end
            if viddif>timewarn || isnan(viddif);
                warning(['end frame of this snippet appears to be ' num2str(viddif) ' s off from video''s time stamp']);
            end
            oframeTimes{movN(n)} = [oframeTimes{movN(n)} vid.times];
        end
        if ~badmovie; frameTimes{movN(n)} = [frameTimes{movN(n)} vid.times]; end
        if sum(isnan(vid.times)) > 0; lbl = [' with ' num2str(sum(isnan(vid.times))) ' bad data points (will be fixed at movie end)']; else lbl = ''; end
        disp([num2str(endtime) ' sec completed' lbl]);
        videoL = vid.totalDuration;
        if timestamps && ~simpleread; starttime = endtime-0.1; else starttime = endtime; end
        endtime = endtime+dur;
    end
    if ~simpleread
        [frameTimes{movN(n)},numbad,numbadsect] = checkbadframes(frameTimes{movN(n)});
        lbl = [' with ' num2str(numbad) ' frames that could not be read and were interpolated, and ' num2str(numbadsect) ' frames that were shifted and corrected'];
    else if viddif>timewarn; lbl = [', end frame of movie appears to be ' num2str(viddif) ' s off from video''s time stamp']; else lbl = [', and end of video is within time differential threshold (' num2str(viddif) 's)']; end
        viddifs(movN(n)) = viddif;
    end
    
    if timestamps && ~badmovie && ~simpleread
        if badvidDN(movN(n))
            vidDN(movN(n)) = frameTimes{movN(n)}(1);
        end
            frameTimes{movN(n)} = (frameTimes{movN(n)} - frameTimes{movN(n)}(1))*24*60*60;
            %         frameTimes{movN(n)} = round(frameTimes{movN(n)}*30)/30; %easier to read if closer to 1/30 rate?
            if n>1 && vidDN(movN(n)) < vidDN(movN(n-1)); vidDN(movN(n)) = vidDN(movN(n))+1; DAY = DAY+1; end
            % oi = find(diff(vidDN)<0)+1; %find the changes from one day to the next
            %             for ii = 1:length(oi)
            %                 vidDN(oi:end) = vidDN(oi:end)+1;
            %             end

        vidDurs(movN(n)) = frameTimes{movN(n)}(end)+median(diff(frameTimes{movN(n)}));
    end
    disp([movies{n} ' completed' lbl]);
    save([dataloc datafile(1:end-4) 'movieTimesTEMP.mat'],'frameTimes','vidDN','videoL','vidDurs');
    if timestamps; save([dataloc datafile(1:end-4) 'movieTimesTEMP.mat'],'oframeTimes','-append'); end
end

% for i = 1:length(frameTimes)
%     if isempty(frameTimes{i}) || strcmp(m2{movN == i}(end-2:end),'raw'); continue; end
%     fr = median(diff(frameTimes{i}));
%     smallpoints = find(diff(frameTimes{i})<fr/2);
%     if ~isempty(smallpoints)
%         smallpoints
%         disp(['In movie # ' num2str(i)]);
%     end
%     if ~isempty(smallpoints)    
%         [s, e] = consec(smallpoints);
%         for ii = 1:length(s)
%             if e(ii)+2>length(frameTimes{i})||isnan(e(ii)+2)
%                 frameTimes{i}(s(ii):e(ii)+1) = frameTimes{i}(s(ii)):fr:frameTimes{i}(s(ii))+(e(ii)-s(ii)+1)*fr;
%             else
%                 diff2 = frameTimes{i}(e(ii)+3:end)-frameTimes{i}(e(ii)+1:end-2);
%                 nextgood = find(diff2>fr*1.6&diff2<fr*2.2,1)+2+e(ii);
%                 if diff(frameTimes{i}([s(ii) nextgood])) == 0; nextgood = nextgood + 1; end
%                 frameTimes{i}(s(ii):nextgood) = frameTimes{i}(s(ii)):diff(frameTimes{i}([s(ii) nextgood]))/(nextgood-s(ii)):frameTimes{i}(nextgood);
%             end
%         end
%     end
%     
%     if sum([isnan(frameTimes{i}) diff(frameTimes{i})<=0]) >0 || (i>1&&~isempty(frameTimes{i})&&~isempty(frameTimes{i-1}) && any(frameTimes{i-1}/24/60/60+vidDN(i-1)>frameTimes{i}(1)/24/60/60+vidDN(i)))
%         disp(['Check movie #' num2str(i)]);
%     end
% end

if ~timestamps && sum(badvidDN)>= length(movN)
    disp('Using metadata timestamps from video files (times could not be read from video name)')
    disp('Do these timestamps come from the beginning of the video (e.g. gopro?) or the end of the video (e.g. 2k)?');
    s = input('1 = beginning, 2 = end');
    if s == 2;
        vidDN = vidDN - vidDurs/60/60/24;  % new CATS videos from 2k save date stamp at the END of recording rather than the beginning
    end
end

if timestamps && ~simpleread  && ~audioonly% if vid start time is read from the time stamps.
    for n = 1:length(movies)
        if isempty(intersect(movN(n),vidNums)); continue; end
        if ~strcmp(movies{n}(end-2:end),'raw') && n<= mlast;
            DAY = floor(datenum(movies{n}(min(regexp(movies{n},'-'))+1:max(regexp(movies{n},'-'))-1),'yyyymmdd-HHMMSS'));
            vidDN(movN(n)) = DAY+vidDN(movN(n))-floor(vidDN(movN(n)));
            continue;
        end
    end
end

% if exist('shortmovies','var') && ~isempty(shortmovies); disp(['Audio lengths are slightly off in videos: ' num2str(shortmovies) '.  This may suggest a problem with the download, recommend redownloading if possible.']); end
if ~audioonly
figure; hold on; I = 1; numrepeats = zeros(size(vidDN));
title('Plot of frameTimes.  Red stars indicate a jump in time (if no red stars, you should be good)');
for i = 1:length(frameTimes); 
    if isempty(frameTimes{i}); continue; end
    plot(I:I+length(frameTimes{i})-1,vidDN(i)+frameTimes{i}/24/60/60); 
    if ~isempty(frameTimes{i}); text(I,frameTimes{i}(1)/24/60/60+vidDN(i),num2str(i)); end; 
    oi = find(diff(frameTimes{i})>5*median(diff(frameTimes{i})) | diff(frameTimes{i}) < -median(diff(frameTimes{i})));% mark if it's a whole frame backward
    oi2 = find(abs(diff(frameTimes{i})) < median(diff(frameTimes{i}))/2 | (diff(frameTimes{i}) < 0 & diff(frameTimes{i}) > -median(diff(frameTimes{i}))));
    numrepeats(i) = length(oi2); 
    % fix the very close frames that are less than 0 to be just bigger than 0 so that time
    % never decreases.
    oi2 = find((diff(frameTimes{i}) < 0 & diff(frameTimes{i}) > -median(diff(frameTimes{i}))));
    frameTimes{i}(oi2+1) = frameTimes{i}(oi2)+.001;
    if ~isempty(oi); 
%         frameTimes{i} = checkbadframes(frameTimes{i},true,true,i);
%         oi = find(diff(frameTimes{i})>5*median(diff(frameTimes{i})) | diff(frameTimes{i}) < 0);
        plot(I+oi-1,vidDN(i)+frameTimes{i}(oi)/24/60/60,'r*','markersize',8); hold on;
        df = round(1000*diff(frameTimes{i}))/1000;
        for ii = 1:length(oi); text(I+oi(ii)-1,vidDN(i)+frameTimes{i}(oi(ii))/24/60/60,[num2str(df(oi(ii))) ' s jump at vidFrame ' num2str(oi(ii))],'rotation',90,'verticalalignment','bottom'); end
        title('zoom in and check red stars, may have to check videos files and adjust frameTimes and vidDN if there is an error');
    end
    I = I+length(frameTimes{i});
    if (~simpleread || badvidDN(i))&&~isnan(vidDN(i)); disp(['video # ' num2str(i) ' calculated to start at ' datestr(vidDN(i),'HH:MM:SS.fff')]); end
    if simpleread && viddifs(i)>timewarn; disp(['end frame of movie #' num2str(i) ' appears to be ' num2str(viddifs(i)) ' s off from video''s time stamp']); end
    if simpleread && numrepeats(i)~=0; disp(['movie #' num2str(i) ' appears to have ' num2str(numrepeats(i)) ' repeated frames']); end
end; xlabel('Frame #'); 
set(gca,'yticklabel',datestr(get(gca,'ytick'),'HH:MM:SS.fff'));  


frameSize = [vid.width vid.height];
else
    frameSize = [nan nan];
end
vidDurs(movN(mlast)+1:end) = []; frameTimes(movN(mlast)+1:end) = []; vidDN(movN(mlast)+1:end) = []; vidNam(movN(mlast)+1:end) = []; oframeTimes(movN(mlast)+1:end) = [];
save([dataloc datafile(1:end-4) 'movieTimes.mat'],'vidDurs','frameTimes','movies','vidDN','vidNam','frameSize');
if timestamps; save([dataloc datafile(1:end-4) 'movieTimes.mat'],'oframeTimes','-append'); end
disp('movieTimes file saved successfully, truncated to only include on whale files. Can delete movieTimesTEMP if movieTimes is finalized (i.e. no errors).');

warning('on','all');