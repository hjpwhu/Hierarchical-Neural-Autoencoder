function[result]=Forward(docbatch,parameter,isTraining)
    [result]=Forward_Source_Word(docbatch,parameter,isTraining);
    [result]=Forward_Source_Sen(result,docbatch,parameter,isTraining);
    if isTraining==1
        [result]=Forward_Target(result,docbatch,parameter,isTraining);
    end
end

function[result]=Forward_Source_Word(docbatch,parameter,isTraining)
    sourceBatch=docbatch.source_smallBatch;
    result.source_sen_vector=[];
    for i=1:length(sourceBatch)
        batch=sourceBatch{i};
        T=batch.max_length;
        h_t_source_word=cell(parameter.layer_num,T);
        result.c_t_source_word{i}=cell(parameter.layer_num,T);
        result.lstms_source_word{i} = cell(parameter.layer_num,T);
        N=size(batch.Word,1);
        zeroState=zeroMatrix([parameter.hidden,N]);
        for ll=1:parameter.layer_num
            for tt=1:T
                h_t_source_word{ll,tt}=zeroState;
                result.c_t_source_word{i}{ll,tt}=zeroState;
            end
        end
        for t=1:T
            for ll=1:parameter.layer_num
                W=parameter.Word_S{ll};
                if t==1
                    h_t_1=zeroState;
                    c_t_1=zeroState;
                else
                    c_t_1=result.c_t_source_word{i}{ll, t-1};
                    h_t_1=h_t_source_word{ll, t-1};
                end
                if ll==1
                    x_t=parameter.vect(:,batch.Word(:,t));
                else
                    x_t=h_t_source_word{ll-1,t};
                end
                x_t(:,batch.Delete{t})=0;
                h_t_1(:,batch.Delete{t})=0;
                c_t_1(:,batch.Delete{t})=0;
                [result.lstms_source_word{i}{ll, t},h_t_source_word{ll, t},result.c_t_source_word{i}{ll, t}]=lstmUnit(W,parameter,x_t,[],h_t_1,c_t_1,ll,t,isTraining);
                if t==T && ll==parameter.layer_num
                    result.source_sen_vector=[result.source_sen_vector,h_t_source_word{ll,t}];
                    clear h_t_source_word;
                end
            end
        end
    end
    clear x_t;
    clear h_t_1;
    clear c_t_1;
end

function[result]=Forward_Source_Sen(result,docbatch,parameter,isTraining)
    T=docbatch.max_source_sen;
    h_t_source_sen=cell(parameter.layer_num,T);
    result.c_t_source_sen=cell(parameter.layer_num,T);
    result.lstms_source_sen=cell(parameter.layer_num,T);
    result.source_sen=cell(parameter.layer_num,1);
    result.source_each_sen=gpuArray();

    N=size(docbatch.source_sen_matrix,1);
    zeroState=zeroMatrix([parameter.hidden,N]);
    for ll=1:parameter.layer_num
        for tt=1:T
            h_t_source_sen{ll,tt}=zeroState;
            result.c_t_source_sen{ll,tt}=zeroState;
        end
    end
    for t=1:T
        for ll=1:parameter.layer_num
            W=parameter.Sen_S{ll};
            if t==1
                h_t_1=zeroState;
                c_t_1 =zeroState;
            else
                c_t_1 =result.c_t_source_sen{ll, t-1};
                h_t_1 =h_t_source_sen{ll, t-1};
            end
            if ll==1
                x_t=result.source_sen_vector(:,docbatch.source_sen_matrix(:,t));
            else
                x_t=h_t_source_sen{ll-1,t};
            end
            x_t(:,docbatch.source_delete{t})=0;
            h_t_1(:,docbatch.source_delete{t})=0;
            c_t_1(:,docbatch.source_delete{t})=0;
            [result.lstms_source_sen{ll, t},h_t_source_sen{ll, t},result.c_t_source_sen{ll, t}]=lstmUnit(W,parameter,x_t,[],h_t_1,c_t_1,ll,t,isTraining);
            if t==T 
                result.source_sen{ll,1}=h_t_source_sen{ll, t};
            end
            if ll==parameter.layer_num
                result.source_each_sen=[result.source_each_sen,h_t_source_sen{parameter.layer_num,t}];
            end
        end
    end
    clear result.source_sen_vector;
    clear h_t_source_sen;
    clear x_t;
    clear h_t_1;
    clear c_t_1;
end

function[result]=Forward_Target(result,docbatch,parameter,isTraining)
    T=docbatch.max_target_sen;
    result.h_t_target_sen=cell(parameter.layer_num,T);
    result.c_t_target_sen=cell(parameter.layer_num,T);
    result.lstms_target_sen=cell(parameter.layer_num,T);
    N=size(docbatch.target_sen_matrix,1);
    zeroState=zeroMatrix([parameter.hidden,N]);

    for ll=1:parameter.layer_num
        for tt=1:T
            result.h_t_target_sen{ll,tt}=zeroState;
            result.c_t_target_sen{ll,tt}=zeroState;
        end
    end
    result.Target_sen={};
    for sen_tt=1:T
        for ll=1:parameter.layer_num
            W=parameter.Sen_T{ll};
            if sen_tt==1
                h_t_1=result.source_sen{ll,1};
                dim=size(result.c_t_source_sen);
                c_t_1=result.c_t_source_sen{ll,dim(2)};
            else
                c_t_1 =result.c_t_target_sen{ll, sen_tt-1};
                h_t_1 =result.h_t_target_sen{ll, sen_tt-1};
            end
            if ll==1
                Word_List=docbatch.target_word{sen_tt}.Word;
                Word_Delete=docbatch.target_word{sen_tt}.Delete;
                if sen_tt==1 
                    M1=result.source_sen(:,1);
                    dim=size(result.c_t_source_sen);
                    M2=result.c_t_source_sen(:,dim(2));
                else
                    M1=result.h_t_target_sen(:,sen_tt-1);
                    M2=result.c_t_target_sen(:,sen_tt-1);
                end
                result=Forward_Target_Word(result,M1,M2,Word_List,Word_Delete,docbatch,parameter,isTraining,sen_tt);
                x_t=result.Target_sen{sen_tt}.h_t_target_word{parameter.layer_num,size(Word_List,2)};   
                result=Attention(docbatch,result,M1{parameter.layer_num,1},parameter,sen_tt);
                m_t=result.sum_vector{sen_tt};
            else
                x_t=result.h_t_target_sen{ll-1,sen_tt};
                m_t=[];
            end
            x_t(:,docbatch.target_delete{sen_tt})=0;
            h_t_1(:,docbatch.target_delete{sen_tt})=0;
            c_t_1(:,docbatch.target_delete{sen_tt})=0;
            [result.lstms_target_sen{ll,sen_tt},result.h_t_target_sen{ll,sen_tt},result.c_t_target_sen{ll,sen_tt}]=lstmUnit(W,parameter,x_t,m_t,h_t_1,c_t_1,ll,sen_tt,isTraining);
        end
    end
    clear target_sen_vector;
    clear x_t;
    clear h_t_1;
    clear c_t_1;
end

function[result]=Forward_Target_Word(result,h_t_sen,c_t_sen,Word_List,Word_Delete,docbatch,parameter,isTraining,sen_tt)
    N=size(Word_List,1);
    T=size(Word_List,2);
    target_sen.h_t_target_word=cell(parameter.layer_num,T);
    target_sen.c_t_target_word=cell(parameter.layer_num,T);
    target_sen.lstms=cell(parameter.layer_num,T);
    zeroState=zeroMatrix([parameter.hidden,N]);

    for ll=1:parameter.layer_num
        for tt=1:T
            target_sen.h_t_target_word{ll,tt}=zeroState;
            target_sen.c_t_target_word{ll,tt}=zeroState;
        end
    end
    for t=1:T
        for ll=1:parameter.layer_num
            W=parameter.Word_T{ll};
            if t==1
                h_t_1=h_t_sen{ll,1};
                c_t_1=c_t_sen{ll,1};
            else
                c_t_1 =target_sen.c_t_target_word{ll, t-1};
                h_t_1 =target_sen.h_t_target_word{ll, t-1};
            end
            if ll==1
                x_t=parameter.vect(:,Word_List(:,t));
            else
                x_t=target_sen.h_t_target_word{ll-1,t};
            end
            x_t(:,Word_Delete{t})=0;
            h_t_1(:,Word_Delete{t})=0;
            c_t_1(:,Word_Delete{t})=0;
            [target_sen.lstms{ll, t},target_sen.h_t_target_word{ll, t},target_sen.c_t_target_word{ll, t}]=lstmUnit(W,parameter,x_t,[],h_t_1,c_t_1,ll,t,isTraining);
            if t~=1
                target_sen.h_t_target_word{ll, t}(:,Word_Delete{t})=target_sen.h_t_target_word{ll,t-1}(:,Word_Delete{t});
            end
        end
    end
    result.Target_sen{sen_tt}=target_sen;
    clear h_t_1;
    clear c_t_1;
    clear x_t;
end
