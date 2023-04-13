function [V]=calc_Vnode_3ph(ord,f,Ybranch,Vo1,Vo2,Vo3)

V=zeros(2*ord,max(size(f))); % (2*ord x max(size(f)))
Ybranch_dis_f=zeros(2*ord,2*ord); % (2*ord x 2*ord)
for k=1:1:max(size(f))
    
    for o=1:1:2*ord
        Ybranch_dis_f(o,:)=Ybranch(k,(o-1)*2*ord+1:o*2*ord); % ��������� ��� ������ Ybranch ��� ������������� ���������� ��� �������� �� ����������� (2*ord x 2*ord) ���� �� �������������� �� ������� �������
    end
    
    Ired=-Ybranch_dis_f(4:length(Ybranch_dis_f),1)*Vo1(k)-Ybranch_dis_f(4:length(Ybranch_dis_f),2)*Vo2(k)-Ybranch_dis_f(4:length(Ybranch_dis_f),3)*Vo3(k);
    Yred=Ybranch_dis_f(4:length(Ybranch_dis_f),4:length(Ybranch_dis_f)); % ����������� ��� ������ �red ��� �� ������������ ��������� �������� - ((2*ord)-1 x (2*ord)-1)
    %Vred=inv(Yred)*Ired; % ����������� ��� ������ Vred ��� �� ������������ ��������� �������� - ((2*ord)-1 x 1) - ������ � ����������� ��� ����� ����� ���������� �������, ����� ��� ������� ��� �������
    Vred=Yred\Ired;
    Vdis=[Vo1(k);Vo2(k);Vo3(k);Vred]; % ���������� ���� ��� ������ ��� ������ ��� �� ������������ ��������� �������� - (2*ord x 1)
    V(:,k)=Vdis; % ���������� ���� ��� ������ ��� ������ �� ��� �� ����� ���������� - (2*ord x max(size(f)))
end