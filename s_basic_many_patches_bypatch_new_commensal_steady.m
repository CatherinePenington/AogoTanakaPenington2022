%%%%%Code used to produce Fig 2 

function s_basic_many_patches_bypatch_new_commensal_steady
% Model bacteria in many connected patches

infection=0;    % Is an infection occuring? 1 yes, 0 no

% Set parameters
bino_limit = 1000;  % limit (in n) for switching from binomial to normal
stoch_limit = 10^6;  % limit for working out the stochastic result (in n*p)
tsph=10;        % time steps per hour
% tth=720;         % total time in hours
ttd=60;          % total time in days
% displaymult=24;  % record progress through simulation after this many hours
tt=ttd*24*tsph;

dst=24*tsph;
Ks = 1e9;     % Carrying capacity in small intestine
Kl = 1e12;    % Carrying capacity in large intestine
Tr=1;           % bacteria cell cycle length in hours
pr = 2^(1/(Tr*tsph)) -1;       % reproduction rate
del = 0.000;      % natural death rate
pd = 1;       % death rate due to inflammation when inflammation level at 1
Cr = 0.05;       % cost of resistance
Ci = 0.05;       % cost of inflammation
% b = 0.8;        % benefit of resistance
b = 0.8;        
s = 1e-10;        % scaling for inflammation increase
% s = 0;
qq = 0.0004;       % inflammation decay rate
% qq = 0.0; 
n_pat = 60;     % number of patches
n_pat_sm = 30;  % number of patches in small intestine
inflow = 100;  % new cells introduced to patch 1 each time step.
in_normal = 0;  % proportion of old cells that are normal
in_new = 1;     % proportion of new cells that are normal
in_infl = 0;    % proportion of new cells that are inflammation-causing (MUST ADD TO 1)

pm = 0.01;      % rate of active migration
%Tsi = 3;        % time in small intestine (hours)
%Tli = 18;       % time in large intestine (hours)
patch90 = 29;   % patch in small intestine where we reach capacity (<n_pat_sm)
infrac = inflow/Ks;
pf = (pr-del)*patch90/log(9*(1-infrac)/infrac); % rate of flow in small intestine
pflg = pf/6;    % rate of flow in large intestine

% Set up varying pf and K in small and large intestines
pmo = (0.5*pm)*ones(1,n_pat);
pmb = (0.5*pm)*ones(1,n_pat);
K = zeros(1,n_pat);
for pt=1:n_pat_sm
    pmo(pt)=pmo(pt)+pf;
    K(pt)=Ks;
end
for pt=(n_pat_sm+1):n_pat
    pmo(pt)=pmo(pt)+pflg;
    K(pt)=Kl;
end
pmb(1)=0;
pmb(n_pat_sm+1)=0;


% Set up time and initial conditions
% if (infection==0)
% %    x_normal0 = (3*Ks/4)*ones(1,n_pat); % normal bacteria
%     x_normal0 = 1000*ones(1,n_pat);
%     partA=round(n_pat_sm/3);
%     for nnn=partA+1:n_pat_sm
%         x_normal0(nnn)=1e5;
%     end
%     for nnn=n_pat_sm+1:n_pat
%         x_normal0(nnn)=1e7;
%     end
if (infection==0)
    file1A='InitialConditions_Ks_';
    file1B=sprintf('%d',Ks);
    file1C='_Kl_';
    file1D=sprintf('%d',Kl);
    file1E='_patches_';
    file1F=sprintf('%d',n_pat);
    fileG='.mat';
    file1M={file1A,file1B,file1C,file1D,file1E,file1F,fileG};
    filename1a=strjoin(file1M,'');
    
    %Open file and read data
    InputStruct=load(filename1a);
    x_normal0 = round(InputStruct.InCon);
end
x_new0 = zeros(1,n_pat);       % resistant bacteria
x_infl0 = zeros(1,n_pat);       % inflammation-causing bacteria

% Add some inflammation-causing bacteria to patch 1
if (infection==1)
    x_infl0(1)=500;
end

% Set up results matrices
x_normal=zeros(tt+1,n_pat);
x_new=zeros(tt+1,n_pat);
x_infl=zeros(tt+1,n_pat);
Il=zeros(tt+1,n_pat);
x_normal(1,:)=x_normal0;
x_new(1,:)=x_new0;
x_infl(1,:)=x_infl0;
%Il(1,:)=(x_infl0.^beta)/(gm^beta + x_infl0.^beta);


% tic
% etimes=zeros(100,1);
for irep=1:10
% Start time
    for i=1:tt
        % Start with previous values
        x_normal(i+1,:)=x_normal(i,:);
        x_new(i+1,:)=x_new(i,:);
        x_infl(i+1,:)=x_infl(i,:);
        
        % find inflammation at this time step
        for ipt=1:n_pat
            Il(i+1,ipt) = Il(i,ipt) + s*(x_infl(i+1,ipt)) - qq*Il(i,ipt);
        end

        % find which patches contain bacteria of each type
        patches=[nnz(x_normal(i,:)) nnz(x_new(i,:)) nnz(x_infl(i,:))];
        patches_n=find(x_normal(i,:));
        patches_r=find(x_new(i,:));
        patches_f=find(x_infl(i,:));

        patches_n(patches(1)+1:n_pat)=0;
        patches_r(patches(2)+1:n_pat)=0;
        patches_f(patches(3)+1:n_pat)=0;

        % set up "boats" of moving bacteria
        x_normal_bf=zeros(1,n_pat);
        x_normal_bb=zeros(1,n_pat);
        x_new_bf=zeros(1,n_pat);
        x_new_bb=zeros(1,n_pat);
        x_infl_bf=zeros(1,n_pat);
        x_infl_bb=zeros(1,n_pat);

        % create list of not yet reproduced patches for each type of bacteria
        notr=[patches_n; patches_r; patches_f];
        rpa=[0 0 0];

        % create list of not yet died patches for each type of bacteria
        notd=[patches_n; patches_r; patches_f];
        da=[0 0 0];

        % create list of not yet moved patches for each type of bacteria
        notm=[patches_n; patches_r; patches_f];
        ma=[0 0 0];

        % randomly order reproduction, movement and death attempts
        n3=3*(patches(1)+patches(2)+patches(3));
        rord=zeros(1,n3);
        notrd=linspace(1,n3,n3);
        tty=[patches(1) patches(1) patches(2) patches(2) patches(2) patches(3) patches(3) patches(3)];
        for jj=1:8  %%numel(tty)
            jt=sum(tty(1:(jj-1)));
            for ii=1:tty(jj)
                rr1=ceil(rand*(n3-jt-ii));
                rr1(rr1==0)=1;%%%added by rosemary since rr1 returns zero values and thus can not be an index 
%                 rr1= containers.Map('KeyType','uint64','ValueType','double');
                rr=notrd(rr1);
                rord(rr)=jj;
                for irr=rr1:(n3-jt-ii)
                    notrd(irr)=notrd(irr+1);
                end
            end
        end
        if (nnz(rord)~=sum(tty))
            Error_repattempts=nnz(rord)
        end

        for ij=1:n3
            % decide whether attempt is reproduction or death
            if (mod(rord(ij),3)==1)
                % reproduction
                type=floor(rord(ij)/3)+1;
                rpa(type)=rpa(type)+1;

                % choose bacteria patch for attempt at reproduction
                ql=ceil(rand*(patches(type)-rpa(type)+1));
                q=notr(type,ql);
                % find 'resources' available/ carrying capacity
                sumr=x_normal(i+1,q)+x_new(i+1,q)+x_infl(i+1,q);
                if (q>1)
                    sumr=sumr+x_normal_bf(q-1)+x_new_bf(q-1)+x_infl_bf(q-1);
                end
                if (q<n_pat)
                    sumr=sumr+x_normal_bb(q+1)+x_new_bb(q+1)+x_infl_bb(q+1);
                end
                resrem=1-(sumr)/K(q);
                if (resrem<0)
                    resrem=0;
                end

                % reproduce patch (and "boats" if necessary)
                if (type==1)
                    pr_actual=pr*resrem;
                    newbacteria=bino_approx(x_normal(i+1,q),pr_actual);
                    x_normal(i+1,q)=x_normal(i+1,q)+newbacteria;
                    if (x_normal_bf(q)>0 && q<n_pat)
                        sumbf=x_normal(i+1,q+1)+x_new(i+1,q+1)+x_infl(i+1,q+1);
                        sumbf=sumbf+x_normal_bf(q)+x_new_bf(q)+x_infl_bf(q);
                        if (q<(n_pat-1))
                            sumbf=sumbf+x_normal_bb(q+2)+x_new_bb(q+2)+x_infl_bb(q+2);
                        end
                        resrembf=1-sumbf/K(q);
                        if (resrembf<0)
                            resrembf=0;
                        end
                        pr_actual=pr*resrembf;
                        newbacteria=bino_approx(x_normal_bf(q),pr_actual);
                        x_normal_bf(q)=x_normal_bf(q)+newbacteria;
                    end
                    if (x_normal_bb(q)>0)
                        sumbb=x_normal(i+1,q-1)+x_new(i+1,q-1)+x_infl(i+1,q-1);
                        sumbb=sumbb+x_normal_bb(q)+x_new_bb(q)+x_infl_bb(q);
                        if (q>2)
                            sumbb=sumbb+x_normal_bf(q-2)+x_new_bf(q-2)+x_infl_bf(q-2);
                        end
                        resrembb=1-sumbb/K(q);
                        if (resrembb<0)
                            resrembb=0;
                        end
                        pr_actual=pr*resrembb;
                        newbacteria=bino_approx(x_normal_bb(q),pr_actual);
                        x_normal_bb(q)=x_normal_bb(q)+newbacteria;
                    end
                elseif (type==2)
                    pr_actual=pr*resrem;
                    newbacteria=bino_approx(x_new(i+1,q),pr_actual);
                    x_new(i+1,q)=x_new(i+1,q)+newbacteria;
                    if (x_new_bf(q)>0 && q<n_pat)
                        sumbf=x_normal(i+1,q+1)+x_new(i+1,q+1)+x_infl(i+1,q+1);
                        sumbf=sumbf+x_normal_bf(q)+x_new_bf(q)+x_infl_bf(q);
                        if (q<(n_pat-1))
                            sumbf=sumbf+x_normal_bb(q+2)+x_new_bb(q+2)+x_infl_bb(q+2);
                        end
                        resrembf=1-sumbf/K(q);
                        if (resrembf<0)
                            resrembf=0;
                        end
                        pr_actual=pr*resrembf;
                        newbacteria=bino_approx(x_new_bf(q),pr_actual);
                        x_new_bf(q)=x_new_bf(q)+newbacteria;
                    end
                    if (x_new_bb(q)>0)
                        sumbb=x_normal(i+1,q-1)+x_new(i+1,q-1)+x_infl(i+1,q-1);
                        sumbb=sumbb+x_normal_bb(q)+x_new_bb(q)+x_infl_bb(q);
                        if (q>2)
                            sumbb=sumbb+x_normal_bf(q-2)+x_new_bf(q-2)+x_infl_bf(q-2);
                        end
                        resrembb=1-sumbb/K(q);
                        if (resrembb<0)
                            resrembb=0;
                        end
                        pr_actual=pr*resrembb;
                        newbacteria=bino_approx(x_new_bb(q),pr_actual);
                        x_new_bb(q)=x_new_bb(q)+newbacteria;
                    end
                elseif (type==3)
                    pr_actual=pr*(1-Cr)*(1-Ci)*resrem;
                    newbacteria=bino_approx(x_infl(i+1,q),pr_actual);
                    x_infl(i+1,q)=x_infl(i+1,q)+newbacteria;
                    if (x_infl_bf(q)>0 && q<n_pat)
                        sumbf=x_normal(i+1,q+1)+x_new(i+1,q+1)+x_infl(i+1,q+1);
                        sumbf=sumbf+x_normal_bf(q)+x_new_bf(q)+x_infl_bf(q);
                        if (q<(n_pat-1))
                            sumbf=sumbf+x_normal_bb(q+2)+x_new_bb(q+2)+x_infl_bb(q+2);
                        end
                        resrembf=1-sumbf/K(q);
                        if (resrembf<0)
                            resrembf=0;
                        end
                        pr_actual=pr*(1-Cr)*(1-Ci)*resrembf;
                        newbacteria=bino_approx(x_infl_bf(q),pr_actual);
 
                        x_infl_bf(q)=x_infl_bf(q)+newbacteria;
                    end
                    if (x_infl_bb(q)>0)
                        sumbb=x_normal(i+1,q-1)+x_new(i+1,q-1)+x_infl(i+1,q-1);
                        sumbb=sumbb+x_normal_bb(q)+x_new_bb(q)+x_infl_bb(q);
                        if (q>2)
                            sumbb=sumbb+x_normal_bf(q-2)+x_new_bf(q-2)+x_infl_bf(q-2);
                        end
                        resrembb=1-sumbb/K(q);
                        if (resrembb<0)
                            resrembb=0;
                        end
                        pr_actual=pr*(1-Cr)*(1-Ci)*resrembb;
                        newbacteria=bino_approx(x_infl_bb(q),pr_actual);
    %                     if (isnan(newbacteria)==1)
    %                         newbacteria
    %                         xib=x_infl_bb(q)
    %                         pr_actual
    %                         i
    %                         ij
    %                         pause
    %                     end
                        x_infl_bb(q)=x_infl_bb(q)+newbacteria;
                    end
                else
                    Error_notype=type
                end

                % mark patch as reproduced
                for iq=ql:(patches(type)-rpa(type))
                    notr(type,iq)=notr(type,iq+1);
                end
    %            notr=notr(1:n-rpa);

            elseif (mod(rord(ij),3)==2)
                % movement
                type=floor(rord(ij)/3)+1;
                ma(type)=ma(type)+1;

                % choose patch for movement
                ql=ceil(rand*(patches(type)-ma(type)+1));
                q=notm(type,ql);

                % load "boats"
                if (type==1)
                    forwardboat=bino_approx(x_normal(i+1,q),pmo(q));
                    x_normal_bf(q)=forwardboat;
                    x_normal(i+1,q)=x_normal(i+1,q)-forwardboat;
                    backboat=bino_approx(x_normal(i+1,q),pmb(q));
                    x_normal_bb(q)=backboat;
                    x_normal(i+1,q)=x_normal(i+1,q)-backboat;
                elseif (type==2)
                    forwardboat=bino_approx(x_new(i+1,q),pmo(q));
                    x_new_bf(q)=forwardboat;
                    x_new(i+1,q)=x_new(i+1,q)-forwardboat;
                    backboat=bino_approx(x_new(i+1,q),pmb(q));
                    x_new_bb(q)=backboat;
                    x_new(i+1,q)=x_new(i+1,q)-backboat;
                elseif (type==3)
                    forwardboat=bino_approx(x_infl(i+1,q),pmo(q));
                    x_infl_bf(q)=forwardboat;
                    x_infl(i+1,q)=x_infl(i+1,q)-forwardboat;
                    backboat=bino_approx(x_infl(i+1,q),pmb(q));
                    x_infl_bb(q)=backboat;
                    x_infl(i+1,q)=x_infl(i+1,q)-backboat;
                else
                    Error_notype=type
                end

                % mark patch as moved
                for iq=ql:(patches(type)-ma(type))
                    notm(type,iq)=notm(type,iq+1);
                end
    %            notm=notm(1:n-ma);

            else
                % death
                type=floor(rord(ij)/3)+1;
                da(type)=da(type)+1;

                % choose patch for death
                ql=ceil(rand*(patches(type)-da(type)+1));
                q=notd(type,ql);

                % some bacteria die
                if (type==1)
                    pd_actual=del+Il(i+1,q)*pd;
                    if (pd_actual>1)
                        pd_actual=1;
                    end
                    deadbacteria=bino_approx(x_normal(i+1,q),pd_actual);
                    x_normal(i+1,q)=x_normal(i+1,q)-deadbacteria;
                    if (x_normal_bf(q)>0 && q<n_pat)
                        pd_actual=del+Il(i+1,q+1)*pd;
                        deadbacteria=bino_approx(x_normal_bf(q),pd_actual);
  
                        x_normal_bf(q)=x_normal_bf(q)-deadbacteria;
                    end
                    if (x_normal_bb(q)>0)
                        pd_actual=del+Il(i+1,q-1)*pd;
                        deadbacteria=bino_approx(x_normal_bb(q),pd_actual);
                        x_normal_bb(q)=x_normal_bb(q)-deadbacteria;
                    end
                elseif (type==2)
                    pd_actual=del+Il(i+1,q)*pd;
                    if (pd_actual>1)
                        pd_actual=1;
                    end
                    deadbacteria=bino_approx(x_new(i+1,q),pd_actual);
                    x_new(i+1,q)=x_new(i+1,q)-deadbacteria;
                    if (x_new_bf(q)>0 && q<n_pat)
                        pd_actual=del+Il(i+1,q+1)*pd;
                        deadbacteria=bino_approx(x_new_bf(q),pd_actual);
                        x_new_bf(q)=x_new_bf(q)-deadbacteria;
                    end
                    if (x_new_bb(q)>0)
                        pd_actual=del+Il(i+1,q-1)*pd;
                        deadbacteria=bino_approx(x_new_bb(q),pd_actual);
                        x_new_bb(q)=x_new_bb(q)-deadbacteria;
                    end
                elseif (type==3)
                    pd_actual=del+Il(i+1,q)*pd*(1-b);
                    if (pd_actual>1)
                        pd_actual=1;
                    end
                    deadbacteria=bino_approx(x_infl(i+1,q),pd_actual);
                    x_infl(i+1,q)=x_infl(i+1,q)-deadbacteria;
                    if (x_infl_bf(q)>0 && q<n_pat)
                        pd_actual=del+Il(i+1,q+1)*pd;
                        deadbacteria=bino_approx(x_infl_bf(q),pd_actual);
                        x_infl_bf(q)=x_infl_bf(q)-deadbacteria;
                    end
                    if (x_infl_bb(q)>0)
                        pd_actual=del+Il(i+1,q-1)*pd;
                        deadbacteria=bino_approx(x_infl_bb(q),pd_actual);
                        x_infl_bb(q)=x_infl_bb(q)-deadbacteria;
                    end
                else
                    Error_notype=type
                end

                % remove from list of yet to die
                for iq=ql:(patches(type)-da(type))
                    notd(type,iq)=notd(type,iq+1);
                end
    %            notd=notd(1:n-da);

            end
        end

        % unload "boats"
        for pt=1:(n_pat-1)
            x_normal(i+1,pt)=x_normal(i+1,pt)+x_normal_bb(pt+1);
            x_normal(i+1,pt+1)=x_normal(i+1,pt+1)+x_normal_bf(pt);
            x_new(i+1,pt)=x_new(i+1,pt)+x_new_bb(pt+1);
            x_new(i+1,pt+1)=x_new(i+1,pt+1)+x_new_bf(pt);
            x_infl(i+1,pt)=x_infl(i+1,pt)+x_infl_bb(pt+1);
            x_infl(i+1,pt+1)=x_infl(i+1,pt+1)+x_infl_bf(pt);
        end

        % add new bacteria from inflow
        nin1=round(inflow*in_normal);
        x_normal(i+1,1)=x_normal(i+1,1)+nin1;
        nin2=round(inflow*in_new);
        x_new(i+1,1)=x_new(i+1,1)+nin2;
        nin3=round(inflow*in_infl);
        x_infl(i+1,1)=x_infl(i+1,1)+nin3;

        % store the results
%         t=t+1;
%         etimes(irep)=t;
%         disp(irep);
        if (rem(i,dst)==0)
    %        timestep=i
            days=i/dst
            t=i;
        end
%         etimes(irep)=t;
%         disp(irep);
    end
end
% figure(101)
% histogram(etimes);
% xlabel('Time'); ylabel('Frequency'); title('Time to reach stability');
% mean(etimes), std(etimes)


% Set up file names
fileA='Bacteria_Ks_';
if (infection==0)
    fileA='Bacteria_n_only_Ks_';
end
fileB=sprintf('%d',Ks);
fileBX='_Kl_';
fileBY=sprintf('%d',Kl);
fileC='_patches_';
fileD=sprintf('%d',n_pat);
fileE='_normal';
fileF='_new';
fileH='_inflammation-causing';
fileI='_inflammation-level';
fileX='_end';
fileY=sprintf('%d',tt);
fileG='.mat';

% Save results to file
fileM1={fileA,fileB,fileBX,fileBY,fileC,fileD,fileX,fileY,fileE,fileG};
filename1=strjoin(fileM1,'');
save(filename1, 'x_normal');

fileM2={fileA,fileB,fileBX,fileBY,fileC,fileD,fileX,fileY,fileF,fileG};
filename2=strjoin(fileM2,'');
save(filename2, 'x_new');

fileM3={fileA,fileB,fileBX,fileBY,fileC,fileD,fileX,fileY,fileH,fileG};
filename3=strjoin(fileM3,'');
save(filename3, 'x_infl');

fileM4={fileA,fileB,fileBX,fileBY,fileC,fileD,fileX,fileY,fileI,fileG};
filename4=strjoin(fileM4,'');
save(filename4, 'Il');

% End of main function, subfunctions follow

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function bb=bino_approx(n,p)

if (n<bino_limit)
    bb=binornd(n,p);
elseif (n*p<stoch_limit)
    sigq=n*p*(1-p);
    bb=round(normrnd(n*p,sigq));
    if (bb<0)
        bb=0;
    elseif (bb>n)
        bb=n;
    end
else
    bb=round(n*p);
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end  