function Da=accum(D,Cols,pre)
% function Da=accum(D,Cols)
%
% Accumulate records in a data table that share common characteristics.
%
% D is a data table; Cols is a character string which specifies how each column
% should be handled.  Column specifications are as follows (case insensitive):
%
%  m - match column
%  a - accumulate column (numeric)
%  c - concatenate column (char)
%  d - drop column
%
% The function reviews D record by record.  If the entries in the 'match' columns for
% a given record ALL match those of a prior record, the contents of the 'accumulate'
% columns will be summed; the contents of 'concatenate' columns will be
% concatenated to the right.
%
% Columns with 'd' specification will not be included in the result table Da.  The
% result table will have one record for every unique combination of 'match' column
% contents.  It will also have a 'count' column appended which reports the number
% of input records accumulated to make each output record.
% 
% If Cols has fewer entries than D has columns, the remaining columns will be
% dropped.
%
% Accumulated columns are prefixed with 'Accum__' or the optional third argument.  
% Concatenated columns are prefixed with 'Cat__' or, if the optional third
% argument is present and a 2x1 cell array, the second element of the cell array.
% If the third argument is a 3x1 cell array, the third element is the delimiter
% between catenated strings (default '').

PROFILE=true;

if nargin<3
  pre={'Accum__','Cat__',''};
else
  if ~iscell(pre)
    pre={pre, 'Cat__',''};
  else
    switch length(pre)
      case 2
        pre{3}='';
      case 1
        pre{2}='Cat__';
        pre{3}='';
    end
  end
end
    

if isempty(D)
  disp('No input.')
  Da=[];
  return
end

% arg handling
FN=fieldnames(D);
if length(Cols)<length(FN)
  Cols=[Cols repmat('d',1,length(FN)-length(Cols))];
end

tic;
  
% first- drop all nonrequired fields to reduce memory requirements
D=rmfield(D,FN(find(Cols=='d')));
Cols(find(Cols=='d'))='';

% reset fieldnames and grab matches
FN=fieldnames(D);
MatchCols=find(Cols=='m');
NumericMatchCols=[];
% handle no-match case
if length(MatchCols)==0 
  % add dummy field
  [D(1:length(D)).nul]=deal('nul');
  NewFN={'nul'};
else
  FNN=strcat(FN,'__');
  Match=[FNN{MatchCols}]; % name formed from matched fieldnames
  NewFN=FN(MatchCols);
  
  j=1;
  while isempty(D(j).(FN{MatchCols(1)}))
    j=j+1;
  end
  if isnumeric(D(j).(FN{MatchCols(1)}))
    %error('Numeric field!')
    NumericMatchCols=1;
    d=cellfun(@num2str,{D.(FN{MatchCols(1)})}','UniformOutput',0);
    [D(1:length(D)).(Match)]=deal(d{:});
  else
    NumericMatchCols=0;
    [D(1:length(D)).(Match)]=deal(D.(FN{MatchCols(1)}));
  end
  for i=2:length(MatchCols)
    j=1;
    while isempty(D(j).(FN{MatchCols(i)}))
      j=j+1;
    end
    if isnumeric(D(j).(FN{MatchCols(i)}))
      %error('Numeric field!')
      NumericMatchCols=[NumericMatchCols 1];
      d=strcat({D.(Match)}',{'++'},cellfun(@num2str,{D.(FN{MatchCols(i)})}',... 
                                           'UniformOutput',0));
    else
      NumericMatchCols=[NumericMatchCols 0];
      d=strcat({D(:).(Match)}',{'++'},{D(:).(FN{MatchCols(i)})}');
    end
    
    [D(:).(Match)]=deal(d{:});
    %  keyboard
  end
  D=rmfield(D,FN(find(Cols=='m')));
  Cols(find(Cols=='m'))='';
end
Cols=[Cols 'm'];

C=struct2cell(D);
try
  C=reshape(C,size(C,1),size(C,3))';
catch
  l=lasterr;
  %disp(l);
  %disp('For some reason, struct2cell does not seem to be following its protocol')
  %keyboard
  C=C';
end

[d,ind]=sort(C(:,find(Cols=='m'))); % d is sorted list

u=[true; ~strcmp(d(1:end-1),d(2:end))]; % include if different

d=d(u);

FN=fieldnames(D);

AccumCols=find(Cols=='a');
ConcatCols=find(Cols=='c');
na=length(AccumCols);
nc=length(ConcatCols);

for i=1:na
  d(:,1+i)=repmat({0},size(d,1),1);
  NewFN{end+1}=[pre{1} FN{AccumCols(i)}];
end
for j=1:nc
  d(:,1+na+j)=repmat({''},size(d,1),1);
  NewFN{end+1}=[pre{2} FN{ConcatCols(j)}];
end

d(:,end+1)=repmat({0},size(d,1),1);
NewFN{end+1}='Count';

%% set empty accum entries to zero to avoid 1 + [] = [] data loss
if na>0
  Ct=C(:,AccumCols);
  Ct(find(~cellfun(@isnumeric,Ct)))={0};
  Ct(find(cellfun(@isempty,Ct)))={0};
  Ct(find(cellfun(@isnan,Ct)))={0};
  C(:,AccumCols)=Ct;
end
if nc>0
  Ct=C(:,ConcatCols);
  Ct(find(cellfun(@isempty,Ct)))={''};
  C(:,ConcatCols)=Ct;
end

toc;
tic;
for i=1:size(C,1)
  % perform the accumulation
  %nn=find(strcmp(C{i,end},d(:,1)),1);
  n=bisect_find(C{i,end},d(:,1));
  %if n~=nn
  %  keyboard
  %end
  if ~isempty(AccumCols)
    if any(isnan([C{i,AccumCols}]))
      keyboard
    end
    d(n,[2:na+1])=num2cell([d{n,[2:na+1]}]+[C{i,AccumCols}]);
  end
  for j=1:nc
      d{n,1+na+j}=[d{n,1+na+j} C{i,ConcatCols(j)} pre{3}];
  end
  d{n,end}=d{n,end}+1;
  if mod(i,1000)==0
    disp([num2str(i) ' records Processed '])
  toc;
  tic;
  end
end

% now re-break-up the match field
%for i=1:size(d,1)
if isempty(MatchCols)
  d=d(:,2:end);
  NewFN=NewFN(2:end);
else
  dd=regexp(d(:,1),'++','split');  
  try
    d=[reshape([dd{:}],length(MatchCols),size(dd,1))' d(:,2:end)];
  catch
    keyboard
  end
  nmc=find(NumericMatchCols);
  if nmc
    for i=1:length(nmc)
      d(:,nmc(i))=num2cell(cellfun(@str2num,d(:,nmc(i))));
    end
  end
end

Da=cell2struct(d,NewFN,2);
