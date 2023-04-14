%基于huffman编码的JPEG流程
%total_bitstream是带分隔符的输出码流，total_bit是总比特数，rate是压缩比
clear all;
close all;
T=dctmtx(8); %dct8*8矩阵
%图像8*8分块矩阵
A=imread('lena.jpg');
I=double(rgb2gray(A));%转为灰度图，每个像素取值是0到255不是0到1
img_L=size(I,1);%图像长度
img_W=size(I,2);%图像宽度
total_bitstream='';%输出总比特流
%读取DC系数编码表
[dc_val, dc_code] = textread('dc_huffman_table.txt', '%s%s');
for ii=1:8:img_L
    for jj=1:8:img_W
        img1=I(ii:ii+7,jj:jj+7);%每次对8*8子块矩阵进行操作
        %量化矩阵
        q_m = [ 16    11    10    16    24    40    51    61
            12    12    14    19    26    58    60    55
            14    13    16    24    40    57    69    56
            14    17    22    29    51    87    80    62
            18    22    37    56    68   109   103    77
            24    35    55    64    81   104   113    92
            49    64    78    87   103   121   120   101
            72    92    95    98   112   100   103    99];
        img2=img1-128*ones(8,8);%电平位移
        K=T*img2*T';%DCT正变换
        K=round(K./q_m);%量化
        %之字形扫描，得到1*64数组
        [zig_m]=zigzag(K);
        
        %DC系数编码
        dc_diff = zig_m(1);
        if dc_diff == 0
            dc_index = 1;
        else
            dc_index = find(strcmp(dc_val, num2str(dc_diff)));
        end
        dc_code_word = dc_code{dc_index};
        total_bitstream = strcat(total_bitstream, dc_code_word);
        %AC系数编码
        [ac_rs,~,ac_code]=textread('ac_huffman_table.txt','%s%s%s');%读编码表
        %生成编码单位：零游程、SSSS、非0AC系数
        ZRL=0;%零游程
        SSSS=0;
        codeunit=zeros(64,3);%每一行是一个编码单位，零游程、SSSS、非0AC系数
        j=0;%编码单位标号
        for i=2:1:64%DC系数不处理
            if zig_m(i:end)==0
                %EOB
                j=j+1;
                codeunit(j,1)=0;
                codeunit(j,2)=0;
                codeunit(j,3)=-1;%假定EOB的尾码是-1以作区分
                break;
            elseif zig_m(i)==0
                ZRL=ZRL+1;
            else
                if ZRL<16%ZRL是0到15
                    %由尾码得到SSSS
                    j=j+1;
                    if zig_m(i)==0
                        SSSS=0;
                    else
                        SSSS=floor(log2(abs(zig_m(i))))+1;
                    end
                    codeunit(j,1)=ZRL;
                    codeunit(j,2)=SSSS;
                    codeunit(j,3)=zig_m(i);
                    ZRL=0;
                else%ZRL大于15分为两部分编码
                    %16的部分编为(15,0)(0)
                    j=j+1;
                    codeunit(j,1)=15;
                    codeunit(j,2)=0;
                    codeunit(j,3)=0;
                    %第二部分游程减去16，剩下两个正常
                    j=j+1;
                    if zig_m(i)==0
                        SSSS=0;
                    else
                        SSSS=floor(log2(abs(zig_m(i))))+1;
                    end
                    codeunit(j,1)=ZRL-16;
                    codeunit(j,2)=SSSS;
                    codeunit(j,3)=zig_m(i);
                end
            end
        end
        codeunit(all(codeunit==0,2),:)=[];%删除全0行，剩下的即为需要的编码单位
        %DC系数不做处理，仍然是8bit
        DC_num=dec2bin(zig_m(1,1),8);
        total_bitstream=strcat(total_bitstream,DC_num,',');
        %AC系数查表
        for i=1:1:size(codeunit,1)%对codeunit每一行进行操作
            prefix=string(dec2hex(codeunit(i,1)))+'/'+string(dec2hex(codeunit(i,2)));%游程+ssss
            rs_index=strcmp(prefix,ac_rs);%获得匹配的下标
            code_prefix=cell2mat(ac_code(rs_index));%获得前缀的编码
            if codeunit(i,3)>0%尾码大于0取原码
                code_suffix=dec2bin(codeunit(i,3));%尾码的编码
                code_suffix=code_suffix(end-codeunit(i,2)+1:end);%取后SSSS位
            else%尾码不会为0;小于0取反码
                temp1=abs(codeunit(i,3));%取绝对值
                temp2=bitcmp(uint16(temp1));%按位取反
                temp3=dec2bin(temp2);%转换成二进制
                code_suffix=temp3(end-codeunit(i,2)+1:end);%取后SSSS位
            end
            if code_suffix ~= " "%未到达EOB
                total_bitstream=strcat(total_bitstream,code_prefix,',',code_suffix,',');
            else%到达EOB，此时尾码是空，不用输出
                total_bitstream=strcat(total_bitstream,code_prefix,',');
            end
        end
    end
end
total_bitstream=total_bitstream(1:length(total_bitstream)-1);%去掉末尾的分隔符
total_bit=length(find(total_bitstream~=','));%压缩后比特数,去掉分隔符
writematrix(total_bitstream,"total_bitstream.txt");%输出码流至txt文件中
rate=8*img_L*img_W/total_bit;%计算压缩比

fprintf('本次实验压缩比为%f\n',rate);