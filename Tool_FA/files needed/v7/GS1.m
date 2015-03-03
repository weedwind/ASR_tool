function Q = gs1(A)              
%GS     Gram-Schmidt process on the columns of A.
%       Uses the Gram-Schmidt process to construct a matrix Q whose columns
%       form an orthogonal basis for the column space of the matrix A.  The
%       columns of A need not be linearly independent. Normalization is 
%       done on the columns of A.
%
%       Format:    Q = gs1(A)
 
%       Written by David Lay, University of Maryland, College Park
%       Version: 8/3/93  Updated for version 4.0 9/17/95
%       (c) David C. Lay, 1995
%       Revised by Venugopal Jaishree, Old Dominion University, Norfolk
%       on 05/07/1999

[m n] = size(A);

col = 1;

while (col<n & A(:,col)==zeros(m,1))
  col = col+1;
end

if (col==n & A(:,col)==zeros(m,1))
  error('The column space of the zero matrix has no basis.')
end

Q= A(:,col);                    %Place first nonzero column of A into Q               

for k = col+1:n                 %Begin Gram Schmidt orthogonalization process
   proj = zeros(m,1);           %Initialize the projection vector
   [r s] = size(Q);
   for j=1:s
      proj = proj + (A(:,k)'*Q(:,j))/(Q(:,j)'*Q(:,j))*Q(:,j);
   end
   newcol = A(:,k)-proj;        %Possible new column for Q
   if max(abs(newcol))<1024*eps %Don't augment Q with a column whose entries
     newcol = [];               %are so small they probably should be zeros
   end
   Q=[Q newcol];
end

format  
[r s] = size(Q);

for j=1:s
    Q(:,j) = Q(:,j)/norm(Q(:,j),2);
end
