//*************************************************************************************/
///* Copyright (C) 2022 - Renaud Dubois - This file is part of Cairo_musig2 project	 */
///* License: This software is licensed under MIT License 	 */
///* See LICENSE file at the root folder of the project.				 */
///* FILE: ecZZ.solidity							         */
///* 											 */
///* 											 */
///* DESCRIPTION: modified XYZZ system coordinates for EVM elliptic point multiplication
///*  optimization
///* 
//**************************************************************************************/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

 import "hardhat/console.sol";

library Ec_ZZ {
    // Set parameters for curve.
    //curve bitsize
    uint constant curve_S1=255;
    //curve prime field modulus
    uint constant p = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    //short weierstrass first coefficient
    uint constant a =
        0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC;
    //short weierstrass second coefficient    
    uint constant b =
        0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B;
    //generating point affine coordinates    
    uint constant gx =
        0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
    uint constant gy =
        0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;
    //curve order (number of points)
    uint constant n =
        0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;    
    /* -2 constant, used to speed up doubling (avoid negation)*/
    uint constant minus_2 = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFD;
    
    
    
    /**
     * @dev Inverse of u in the field of modulo m.
     */
    function inverseMod(uint u, uint m) internal pure returns (uint) {
        if (u == 0 || u == m || m == 0) return 0;
        if (u > m) u = u % m;

        int t1;
        int t2 = 1;
        uint r1 = m;
        uint r2 = u;
        uint q;
        unchecked {
            while (r2 != 0) {
                q = r1 / r2;
                (t1, t2, r1, r2) = (t2, t1 - int(q) * t2, r2, r1 - q * r2);
            }

            if (t1 < 0) return (m - uint(-t1));

            return uint(t1);
        }
    }

    /**
     * @dev Transform affine coordinates into projective coordinates.
     */
    function toProjectivePoint(
        uint x0,
        uint y0
    ) internal pure returns (uint[3] memory P) {
        unchecked {
            P[2] = addmod(0, 1, p);
            P[0] = mulmod(x0, P[2], p);
            P[1] = mulmod(y0, P[2], p);
        }
    }


    function ecAff_SetZZ(
        uint x0,
        uint y0
    ) internal pure returns (uint[4] memory P) {
        unchecked {
            P[2] = 1; //ZZ
            P[3] = 1; //ZZZ
            P[0] = x0;
            P[1] = y0;
        }
    }
    
/*    https://hyperelliptic.org/EFD/g1p/auto-shortw-xyzz-3.html#addition-add-2008-s*/
    function ecZZ_SetAff( uint x,
        uint y,
        uint zz,
        uint zzz) internal pure returns (uint x1, uint y1)
    {
      uint zzzInv = inverseMod(zzz, p); //1/zzz
      y1=mulmod(y,zzzInv,p);//Y/zzz
      uint b=mulmod(zz, zzzInv,p); //1/z
      zzzInv= mulmod(b,b,p); //1/zz
      x1=mulmod(x,zzzInv,p);//X/zz
    }
    
 
    
    /* Chudnosky doubling*/
    /* The "dbl-2008-s-1" doubling formulas */
    
    function ecZZ_Dbl(
    	uint x,
        uint y,
        uint zz,
        uint zzz
    ) internal pure returns (uint P0, uint P1,uint P2,uint P3)
    {
     unchecked{
     //use output as temporary to reduce RAM usage
     P0=mulmod(2, y, p); //U = 2*Y1
     P2=mulmod(P0,P0,p); // V=U^2
     P3=mulmod(x, P2,p); // S = X1*V
     P1=mulmod(P0, P2,p); // W=UV
    
     P2=mulmod(P2, zz, p); //zz3=V*ZZ1
     
     zz=mulmod(addmod(x,p-zz,p), addmod(x,zz,p),p);//M=3*(X1-ZZ1)*(X1+ZZ1), use zz to reduce RAM usage
     zz=mulmod(3,zz, p);//M
     P0=addmod(mulmod(zz,zz,p), mulmod(minus_2, P3,p),p);//X3=M^2-2S
     
     P3=addmod(P3, p-P0,p);//S-X3
     x=mulmod(zz,P3,p);//M(S-X3)
     P3=mulmod(P1,zzz,p);//zzz3=W*zzz1

     P1=addmod(x, p-mulmod(P1, y,p),p );//Y3= M(S-X3)-W*Y1
     }
     
     return (P0, P1, P2, P3);
    }
    
     /**
     * @dev add a ZZ point with a normalized point and greedy formulae
     */
     
    //tbd: 
    // return -x1 and -Y1 in double
    function ecZZ_AddN(
    	uint x1,
        uint y1,
        uint zz1,
        uint zzz1,
        uint x2,
        uint y2) internal pure returns (uint P0, uint P1,uint P2,uint P3)
     {
      
     unchecked{
      y1=p-y1;//-Y1
      //U2 = X2*ZZ1
      x2=mulmod(x2, zz1,p);
      //S2 = Y2*ZZZ1, y2 free
      y2=mulmod(y2, zzz1,p);
      //R = S2-Y1
      y2=addmod(y2,y1,p);
      //P = U2-X1
      x2=addmod(x2,p-x1,p);
     
      
      P0=mulmod(x2, x2, p);//PP = P^2
     
      P1=mulmod(P0,x2,p); //PPP = P*PP
     
      P2=mulmod(zz1,P0,p); //ZZ3 = ZZ1*PP
     
      P3= mulmod(zzz1,P1,p); //ZZZ3 = ZZZ1*PPP
     
      zz1=mulmod(x1, P0, p);  //Q = X1*PP, x1 free
      //X3 = R^2-PPP-2*Q
      P0= addmod(mulmod(y2,y2, p), p-P1,p ); //R^2-PPP
      zzz1=mulmod(minus_2, zz1,p);//-2*Q
      P0=addmod(P0, zzz1 ,p );//R^2-PPP-2*Q
      //Y3 = R*(Q-X3)-Y1*PPP
      x1= mulmod(addmod(zz1, p-P0,p), y2, p);//R*(Q-X3)
      P1=addmod(x1, mulmod(y1, P1,p),p)  ;
      }
      return (P0, P1, P2, P3);
     }
        
    /**
     * @dev Add two points in affine coordinates and return projective point.
     */
    function addAndReturnProjectivePoint(
        uint x1,
        uint y1,
        uint x2,
        uint y2
    ) internal pure returns (uint[3] memory P) {
        uint x;
        uint y;
        unchecked {
            (x, y) = add(x1, y1, x2, y2);
        }
        P = toProjectivePoint(x, y);
    }

    /**
     * @dev Transform from projective to affine coordinates.
     */
    function toAffinePoint(
        uint x0,
        uint y0,
        uint z0
    ) internal pure returns (uint x1, uint y1) {
        uint z0Inv;
        unchecked {
            z0Inv = inverseMod(z0, p);
            x1 = mulmod(x0, z0Inv, p);
            y1 = mulmod(y0, z0Inv, p);
        }
    }
    
  /**
     * @dev Transform from jacobian to affine coordinates.
     */
  function toAffinePoint_FromJac(
        uint x0,
        uint y0,
        uint z0
    ) internal pure returns (uint x1, uint y1) {
        uint z0Inv;
        unchecked {
            z0Inv = inverseMod(z0, p);
            uint z0Inv2 = mulmod(z0Inv,z0Inv, p);
            x1 = mulmod(x0, z0Inv2, p); //x=X/Z^2
            z0Inv = mulmod(z0Inv2,z0Inv, p);
            y1 = mulmod(y0, z0Inv, p);//y=X/Z^3
        }
    }


    /**
     * @dev Return the zero curve in projective coordinates.
     */
    function zeroProj() internal pure returns (uint x, uint y, uint z) {
        return (0, 1, 0);
    }

  /**
     * @dev Return the zero curve in chudnosky coordinates.
     */
    function ecZZ_SetZero() internal pure returns (uint x, uint y, uint zz, uint zzz) {
        return (0, 0, 0, 0);
    }
    
    function ecZZ_IsZero (uint x0, uint y0, uint zz0, uint zzz0) internal pure returns (bool)
    {
     if ( (x0 == 0) && (y0 == 0) && (zz0==0) && (zzz0==0) ) {
            return true;
        }
        return false;
    }
    /**
     * @dev Return the zero curve in affine coordinates. Compatible with the double formulae (no special case)
     */
    function ecAff_SetZero() internal pure returns (uint x, uint y) {
        return (0, 0);
    }

    /**
     * @dev Check if the curve is the zero curve in affine rep.
     */
    function isZeroCurve_affine(uint x0, uint y0) internal pure returns (bool isZero) {
        if (x0 == 0 && y0 == 0) {
            return true;
        }
        return false;
    }
    
     function isZeroCurve_proj(uint x0, uint y0, uint z0) internal pure returns (bool isZero) {
        if ( (x0 == 0) && (y0 == 1) && (z0==0) ) {
            return true;
        }
        return false;
    }
    

    /**
     * @dev Check if a point in affine coordinates is on the curve.
     */
    function isOnCurve(uint x, uint y) internal pure returns (bool) {
        if (0 == x || x == p || 0 == y || y == p) {
            return false;
        }
        unchecked {
            uint LHS = mulmod(y, y, p); // y^2
            uint RHS = mulmod(mulmod(x, x, p), x, p); // x^3

            if (a != 0) {
                RHS = addmod(RHS, mulmod(x, a, p), p); // x^3 + a*x
            }
            if (b != 0) {
                RHS = addmod(RHS, b, p); // x^3 + a*x + b
            }

            return LHS == RHS;
        }
    }
    
    
    /**
     * @dev Double an elliptic curve point in projective coordinates. See
     * https://www.nayuki.io/page/elliptic-curve-point-addition-in-projective-coordinates
     */
    function twiceProj(
        uint x0,
        uint y0,
        uint z0
    ) internal pure returns (uint x1, uint y1, uint z1) {
        uint t;
        uint u;
        uint v;
        uint w;

        if (isZeroCurve_proj(x0, y0, z0)) {
            return zeroProj();
        }
        unchecked {
            u = mulmod(y0, z0, p);
            u = mulmod(u, 2, p);

            v = mulmod(u, x0, p);
            v = mulmod(v, y0, p);
            v = mulmod(v, 2, p);

            x0 = mulmod(x0, x0, p);
            t = mulmod(x0, 3, p);

            z0 = mulmod(z0, z0, p);
            z0 = mulmod(z0, a, p);
            t = addmod(t, z0, p);

            w = mulmod(t, t, p);
            x0 = mulmod(2, v, p);
            w = addmod(w, p - x0, p);

            x0 = addmod(v, p - w, p);
            x0 = mulmod(t, x0, p);
            y0 = mulmod(y0, u, p);
            y0 = mulmod(y0, y0, p);
            y0 = mulmod(2, y0, p);
            y1 = addmod(x0, p - y0, p);

            x1 = mulmod(u, w, p);

            z1 = mulmod(u, u, p);
            z1 = mulmod(z1, u, p);
        }
    }

    /**
     * @dev Add two elliptic curve points in projective coordinates. See
     * https://www.nayuki.io/page/elliptic-curve-point-addition-in-projective-coordinates
     */
    function addProj(
        uint x0,
        uint y0,
        uint z0,
        uint x1,
        uint y1,
        uint z1
    ) internal pure returns (uint x2, uint y2, uint z2) {
        uint t0;
        uint t1;
        uint u0;
        uint u1;

        if (isZeroCurve_proj(x0, y0, z0)) {
            return (x1, y1, z1);
       
        } else if (isZeroCurve_proj(x1, y1, z1)) {
            return (x0, y0, z0);
        }
      	
        unchecked {
            t0 = mulmod(y0, z1, p);
            t1 = mulmod(y1, z0, p);

            u0 = mulmod(x0, z1, p);
            u1 = mulmod(x1, z0, p);
        }
        if (u0 == u1) {
            if (t0 == t1) {
                return twiceProj(x0, y0, z0);
            } else {
                return zeroProj();
            }
        }
        unchecked {
            (x2, y2, z2) = addProj2(mulmod(z0, z1, p), u0, u1, t1, t0);
        }
        
     
    }

    /**
     * @dev Helper function that splits addProj to avoid too many local variables.
     */
    function addProj2(
        uint v,
        uint u0,
        uint u1,
        uint t1,
        uint t0
    ) private pure returns (uint x2, uint y2, uint z2) {
        uint u;
        uint u2;
        uint u3;
        uint w;
        uint t;

        unchecked {
            t = addmod(t0, p - t1, p);
            u = addmod(u0, p - u1, p);
            u2 = mulmod(u, u, p);

            w = mulmod(t, t, p);
            w = mulmod(w, v, p);
            u1 = addmod(u1, u0, p);
            u1 = mulmod(u1, u2, p);
            w = addmod(w, p - u1, p);

            x2 = mulmod(u, w, p);

            u3 = mulmod(u2, u, p);
            u0 = mulmod(u0, u2, p);
            u0 = addmod(u0, p - w, p);
            t = mulmod(t, u0, p);
            t0 = mulmod(t0, u3, p);

            y2 = addmod(t, p - t0, p);

            z2 = mulmod(u3, v, p);
        }
    }

    /**
     * @dev Add two elliptic curve points in affine coordinates.
     */
    function add(
        uint x0,
        uint y0,
        uint x1,
        uint y1
    ) internal pure returns (uint, uint) {
        uint z0;

        (x0, y0, z0) = addProj(x0, y0, 1, x1, y1, 1);

        return toAffinePoint(x0, y0, z0);
    }

    /**
     * @dev Double an elliptic curve point in affine coordinates.
     */
    function twice(uint x0, uint y0) internal pure returns (uint, uint) {
        uint z0;

        (x0, y0, z0) = twiceProj(x0, y0, 1);

        return toAffinePoint(x0, y0, z0);
    }

    /**
     * @dev Multiply an elliptic curve point by a 2 power base (i.e., (2^exp)*P)).
     */
    function multiplyPowerBase2(
        uint x0,
        uint y0,
        uint exp
    ) internal pure returns (uint, uint) {
        uint base2X = x0;
        uint base2Y = y0;
        uint base2Z = 1;

        for (uint i = 0; i < exp; i++) {
            (base2X, base2Y, base2Z) = twiceProj(base2X, base2Y, base2Z);
        }

        return toAffinePoint(base2X, base2Y, base2Z);
    }

    /**
     * @dev Multiply an elliptic curve point by a scalar.
     */
    function multiplyScalar(
        uint x0,
        uint y0,
        uint scalar
    ) internal  returns (uint x1, uint y1) {
        if (scalar == 0) {
            return ecAff_SetZero();
        } else if (scalar == 1) {
            return (x0, y0);
        } else if (scalar == 2) {
            return twice(x0, y0);
        }

        uint base2X = x0;
        uint base2Y = y0;
        uint base2Z = 1;
        uint z1 = 1;
        x1 = x0;
        y1 = y0;

        if (scalar % 2 == 0) {
            x1 =0;
            y1=1;
        }

	unchecked{
        scalar = scalar >> 1;

        while (scalar > 0) {
            (base2X, base2Y, base2Z) = twiceProj(base2X, base2Y, base2Z);

            if (scalar % 2 == 1) {
                (x1, y1, z1) = addProj(base2X, base2Y, base2Z, x1, y1, z1);
            }

            scalar = scalar >> 1;
        }
	}
        return toAffinePoint(x1, y1, z1);
    }

  /**
     * @dev Double and Add, MSB to LSB version
     */
    function ecZZ_mul(
        uint x0,
        uint y0,
        uint scalar
    ) internal  returns (uint x1, uint y1) {
        if (scalar == 0) {
            return ecAff_SetZero();
        } 
        
	uint  zzZZ; uint  zzZZZ;
        
	uint bit_mul=(1<<curve_S1);
	bool flag=false;
	int index=int(curve_S1);
	
	console.log("--first msb at position of scalar", bit_mul);
	
	unchecked
	{
      
        //search MSB bit
        while(( scalar & bit_mul)==0  ){
              	bit_mul=bit_mul>>1;
        	index=index-1;
        }
         console.log("--first msb at position of scalar", uint(index));
       
        //R=P
        x1=x0;y1=y0;zzZZ=1;zzZZZ=1;
        index=index-1;	bit_mul=bit_mul>>1;
     
        while (index >= 0) {
         
       
            (x1, y1, zzZZ, zzZZZ) = ecZZ_Dbl(x1, y1, zzZZ, zzZZZ);

            if (bit_mul &scalar != 0) {
                (x1, y1, zzZZ, zzZZZ)= ecZZ_AddN(x1, y1, zzZZ, zzZZZ, x0, y0);
            }

            bit_mul = bit_mul >> 1;
            index=index-1;
        }
	}

	
        return ecZZ_SetAff(x1, y1, zzZZ, zzZZZ);
    }
    
   function NormalizedX(  uint Gx0, uint Gy0, uint Gz0) internal returns(uint px)
   {
       if (Gz0 == 0) {
            return 0;
        }

        uint Px = inverseMod(Gz0, p);
        unchecked {
            Px = mulmod(Gx0, Px, p);
        }
        return Px;
   }
   
 /**
     * @dev Double base multiplication using windowing and Shamir's trick
     */
    function ec_mulmuladd_W(
        uint Gx0,
        uint Gy0,
        uint Qx0,
        uint Qy0,
        uint scalar_u,
        uint scalar_v
    ) internal  returns (uint[3] memory R) {
        
      //1. Precomputation steps: 2 bits window+shamir   
      // precompute all aG+bQ in [0..3][0..3]
      uint [3][16] memory Window;
      
     (Window[0][0], Window[0][1], Window[0][2])= zeroProj();
      
      
      Window[1][0]=Gx0;
      Window[1][1]=Gy0;
      Window[1][2]=1;
      
      Window[2][0]=Qx0;
      Window[2][1]=Qy0;
      Window[2][2]=1;

      (Window[3][0], Window[3][1], Window[3][2])=addProj(Gx0, Gy0, 1, Qx0, Qy0, 1); //3:G+Q
      (Window[4][0], Window[4][1], Window[4][2])=twiceProj(Gx0, Gy0, 1);//4:2G
      (Window[5][0], Window[5][1], Window[5][2])=addProj(Gx0, Gy0, 1, Window[4][0], Window[4][1], Window[4][2]); //5:3G
      (Window[6][0], Window[6][1], Window[6][2])=addProj(Qx0, Qy0, 1, Window[4][0], Window[4][1], Window[4][2]); //6:2G+Q
      (Window[7][0], Window[7][1], Window[7][2])=addProj(Qx0, Qy0, 1, Window[5][0], Window[5][1], Window[5][2]); //7:3G+Q
      (Window[8][0], Window[8][1], Window[8][2])=twiceProj(Qx0, Qy0, 1);//8:2Q
     
      (Window[9][0], Window[9][1], Window[9][2])=addProj(Gx0, Gy0, 1, Window[8][0], Window[8][1], Window[8][2]);//9:2Q+G
      (Window[10][0], Window[10][1], Window[10][2])=addProj(Qx0, Qy0, 1, Window[8][0], Window[8][1], Window[8][2]);//10:3Q
      (Window[11][0], Window[11][1], Window[11][2])=addProj(Gx0, Gy0, 1, Window[10][0], Window[10][1], Window[10][2]); //11:3Q+G
      (Window[12][0], Window[12][1], Window[12][2])=addProj(Window[8][0], Window[8][1], Window[8][2] , Window[4][0], Window[4][1], Window[4][2]); //12:2Q+2G
      (Window[13][0], Window[13][1], Window[13][2])=addProj(Window[8][0], Window[8][1], Window[8][2] , Window[5][0], Window[5][1], Window[5][2]); //13:2Q+3G
      (Window[14][0], Window[14][1], Window[14][2])=addProj(Window[10][0], Window[10][1], Window[10][2], Window[4][0], Window[4][1], Window[4][2]); //14:3Q+2G
      (Window[15][0], Window[15][1], Window[15][2])=addProj(Window[10][0], Window[10][1], Window[10][2],  Window[5][0], Window[5][1], Window[5][2]); //15:3Q+3G
    
    
     //initialize R with infinity point
     (R[0],R[1],R[2])= zeroProj();
     
     uint quadbit=1;
     //2. loop over scalars from MSB to LSB:
     unchecked{
     for(uint8 i=0;i<128;i++)
     {
       uint8 rshift=255-(2*i); 
       (R[0],R[1],R[2])=twiceProj(R[0],R[1],R[2]);//double
       (R[0],R[1],R[2])=twiceProj(R[0],R[1],R[2]);//double
       
     //compute quadruple (8*v1 +4*u1+ 2*v0 + u0)
      	quadbit=8*((scalar_v>>rshift)&1)+ 4*((scalar_u>>rshift)&1)+ 2*((scalar_v>>(rshift-1))&1)+ ((scalar_u >>(rshift-1))&1);
      	
      
        (R[0],R[1],R[2])=addProj(R[0],R[1],R[2], Window[quadbit][0], Window[quadbit][1], Window[quadbit][2]);     
        
     }
     }
     
      return R;
    }


    function ec_mulmuladd_S(
        uint Gx0,
        uint Gy0,
        uint Qx0,
        uint Qy0,
        uint scalar_u,
        uint scalar_v
    ) internal   returns (uint[3] memory R) {

	uint[3] memory H;//G+Q
	(H[0],H[1], H[2] )=addProj(Gx0, Gy0, 1, Qx0, Qy0, 1);
	
		console.log("H=", H[0], H[1], H[2]);
     
     
	uint dibit;
	
      //initialize R with infinity point
     (R[0],R[1],R[2])= zeroProj();
     
     unchecked {
      for(uint index=0;index<256;index ++)
      {
      
       uint i=255-index; 
        
     	if (isZeroCurve_proj(R[0],R[1],R[2])){
        }
        
        
       (R[0],R[1],R[2])=twiceProj(R[0],R[1],R[2]);//double
     
     	if (isZeroCurve_proj(R[0],R[1],R[2])){
        }
        
     	dibit=((scalar_u>>i)&1)+2*((scalar_v>>i)&1);

     	if(dibit==1){
     	 (R[0],R[1],R[2])= addProj(R[0],R[1],R[2],Gx0, Gy0, 1);
        }
        if(dibit==2){
     	 (R[0],R[1],R[2])= addProj(R[0],R[1],R[2],Qx0, Qy0, 1);
        }
        if(dibit==3){
         
  	 (R[0],R[1],R[2])= addProj(R[0],R[1],R[2],H[0],H[1], H[2]);
	}
     }
     }
      return R;
    }
    
    struct Indexing_t{
      uint dibit;
      uint index;
      uint i;
      
    }
    
     function ecZZ_mulmuladd_S(
        uint Gx0,
        uint Gy0,
        uint Qx0,
        uint Qy0,
        uint scalar_u,
        uint scalar_v
    ) internal   returns (uint R0, uint R1) {
     Indexing_t memory Ind;
     
     uint[2] memory R;
     uint[2] memory H;//G+Q
     (H[0], H[1] )=add(Gx0, Gy0, Qx0, Qy0);
     
	
     Ind.index=0;
     {
     Ind.i=255-Ind.index;
     
     while( ((scalar_u>>Ind.i)&1)+2*((scalar_v>>Ind.i)&1) ==0){
      Ind.index=Ind.index+1;
      Ind.i=255-Ind.index; 
     }
     Ind.dibit=((scalar_u>>Ind.i)&1)+2*((scalar_v>>Ind.i)&1);
     if(Ind.dibit==1){
     	 (R0 ,R1 ,R[0], R[1])= (Gx0, Gy0,1,1);
     }
     if(Ind.dibit==2){
        (R0 ,R1,R[0], R[1])= (Qx0, Qy0,1,1);
     }
     if(Ind.dibit==3){ 
  	(R0 ,R1,R[0], R[1])= (H[0], H[1], 1, 1);
     }
     
     Ind.index=Ind.index+1;
     Ind.i=255-Ind.index; 
     }
     
     unchecked {
      for(;Ind.index<256;Ind.index ++)
      {
      
       Ind.i=255-Ind.index; 
        
       (R0 ,R1,R[0], R[1])=ecZZ_Dbl(R0 ,R1,R[0], R[1]);//double
     
     	
        
     	Ind.dibit=((scalar_u>>Ind.i)&1)+2*((scalar_v>>Ind.i)&1);

     	if(Ind.dibit==1){
     	 (R0 ,R1,R[0], R[1])= ecZZ_AddN(R0 ,R1,R[0],R[1], Gx0, Gy0);
        }
        if(Ind.dibit==2){
     	 (R0 ,R1,R[0], R[1])= ecZZ_AddN(R0 ,R1,R[0],R[1], Qx0, Qy0);
        }
        if(Ind.dibit==3){
         
  	 (R0 ,R1,R[0], R[1])= ecZZ_AddN(R0 ,R1,R[0],R[1],  H[0], H[1]);
	}
     }
     }
      return (R0 ,R1);
    }
    
    /**
     * @dev 8 dimensional Shamir/Pippinger, will be done externally, validation purpose only
     */
    function Precalc_Shamir8( uint[2] memory Q) internal pure returns( uint[2][256] memory Prec)
    {
     uint index;
     uint[2][8] memory PowerPQ;
     
     PowerPQ[0][0]=gx;
     PowerPQ[0][1]=gy;
     PowerPQ[4][0]=Q[0];
     PowerPQ[4][1]=Q[1];
     
     for(uint i=1;i<4;i++){
       (PowerPQ[i][0],   PowerPQ[i][1])=twice(PowerPQ[i-1][0],   PowerPQ[i-1][1]);
       (PowerPQ[i+4][0],   PowerPQ[i+4][1])=twice(PowerPQ[i+3][0],   PowerPQ[i+3][1]);
     
     }
     	
     for(uint i=1;i<256;i++)
     {       
        Prec[i][0]=0;
        Prec[i][1]=0;
        
        for(uint j=0;j<8;j++)
        {
        	if(i&(1<<j)!=0){
        		add(PowerPQ[j][0], PowerPQ[j][1], Prec[i][0], Prec[i][1]);
        	}
        }
     }
     return Prec;
    }
    
    function ecZZ_mulmuladd_S8(uint scalar_u, uint scalar_v, uint[2][256] memory Shamir8) internal pure returns(uint x,uint y)
    {
      uint octobit;uint index;
      index=255;
      uint[2] memory R;
       
      octobit=128*(scalar_v>>index)+64*(scalar_v>>(index-64))+32*(scalar_v>>(index-128))+16*(scalar_v>>(index-192))+
               8*(scalar_u>>index)+4*(scalar_u>>(index-64))+2*(scalar_u>>(index-128))+(scalar_u>>(index-192));
               
      (x,y,R[0], R[1])= (Shamir8[octobit][0],     Shamir8[octobit][1],1,1);
      //loop over 1/4 of scalars
      for(index=254; index>=192; index--)
      {
       octobit=128*(scalar_v>>index)+64*(scalar_v>>(index-64))+32*(scalar_v>>(index-128))+16*(scalar_v>>(index-192))+
        8*(scalar_u>>index)+4*(scalar_u>>(index-64))+2*(scalar_u>>(index-128))+(scalar_u>>(index-192));
       
        (x,y,R[0], R[1])=ecZZ_AddN(   x,y,R[0], R[1], Shamir8[octobit][0],     Shamir8[octobit][1]); 
      }
      (x,y)=ecZZ_SetAff(x,y,R[0], R[1]);
    }
    
    /**
     * @dev Multiply the curve's generator point by a scalar.
     */
    function multipleGeneratorByScalar(
        uint scalar
    ) internal  returns (uint, uint) {
        return multiplyScalar(gx, gy, scalar);
    }

    function test_ecZZ_formulae() internal returns(bool)
    {
       uint[4] memory P2ZZ;
        (P2ZZ[0], P2ZZ[1],P2ZZ[2],P2ZZ[3])=ecZZ_Dbl(gx, gy, 1,1);
        uint[2] memory P2;
        (P2[0], P2[1])=twice(gx, gy);
        

        
        /* test normalization*/
	/*        
        P2ZZ[2]=mulmod(0xFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF, p);
        P2ZZ[3]=mulmod(P2ZZ[2], 0xFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF, p);
        P2ZZ[0]=mulmod(gx, P2ZZ[2],p);
        P2ZZ[1]=mulmod(gy, P2ZZ[3],p);
        */
        console.log("-- pre normalization %s", P2ZZ[0], P2ZZ[1]);
        console.log("-- pre normalization %s", P2ZZ[2], P2ZZ[3]);
      
        uint[2] memory P2zz;
        (P2zz[0], P2zz[1])=ecZZ_SetAff(P2ZZ[0], P2ZZ[1],P2ZZ[2],P2ZZ[3]);   
        bool isonc=isOnCurve(P2zz[0], P2zz[1]);
        console.log("--is on curve", isonc);
      
        
        console.log("res 1 post norm:", P2zz [0], P2zz[1]);
        console.log("res 2:", P2 [0], P2[1]);
        
     
        (P2ZZ[0], P2ZZ[1],P2ZZ[2],P2ZZ[3])=ecZZ_AddN( P2ZZ[0], P2ZZ[1],P2ZZ[2],P2ZZ[3], gx, gy);//3P in ZZ coordinates
        (P2zz[0], P2zz[1])=ecZZ_SetAff(P2ZZ[0], P2ZZ[1],P2ZZ[2],P2ZZ[3]);   
        isonc=isOnCurve(P2zz[0], P2zz[1]);
        
        
        console.log("--is on curve", isonc);
        
        (P2[0], P2[1])=add(P2[0], P2[1], gx, gy);
        
        console.log("3P via ZZ", P2zz [0], P2zz[1]);
        console.log("3P via Aff:", P2 [0], P2[1]);
        
        return true;
    }
    /**
     * @dev Validate combination of message, signature, and public key.
     */
    function validateSignature(
        bytes32 message,
        uint[2] memory rs,
        uint[2] memory Q
    ) internal  returns (bool) {
        if (rs[0] == 0 || rs[0] >= n || rs[1] == 0) {
            return false;
        }
        if (!isOnCurve(Q[0], Q[1])) {
            return false;
        }
  	
      

        uint sInv = inverseMod(rs[1], n);
        uint scalar_u=mulmod(uint(message), sInv, n);
        uint scalar_v= mulmod(rs[0], sInv, n);
 		
        // without Optim
        
      
 	
 	uint x1;
        uint x2;
        uint y1;
        uint y2;
        
        /*
        (x1, y1) = multiplyScalar(gx, gy, scalar_u);
        (x2, y2) = multiplyScalar(Q[0], Q[1], scalar_v);
        //uint[3] memory PAff = addAndReturnProjectivePoint(x1, y1, x2, y2);
        
        console.log("res naive Aff mul1:", x1, y1);
        console.log("res naive Aff mul2:", x2, y2);
        */
        
        
       // (x1, y1) = ecZZ_mul(gx, gy, scalar_u);
       // (x2, y2) = ecZZ_mul(Q[0], Q[1], scalar_v);
        
        
       // console.log("res naive ZZ:", x1, y1);
       // console.log("res naive ZZ:", x2, y2);
	      
        //test_ecZZ_formulae();
     
        //Shamir 2 dimensions 
        (x1, y1)=ecZZ_mulmuladd_S(gx, gy, Q[0], Q[1],scalar_u, scalar_v);
       
       
        
	//uint[3] memory P = ec_mulmuladd_W(gx, gy, Q[0], Q[1],scalar_u ,scalar_v );
 	//uint Px=NormalizedX(P[0], P[1], P[2]);
 	
        //return Px % n == rs[0];
        return true;
    }
    
     function validateSignature_Precomputed(
        bytes32 message,
        uint[2] memory rs,
        uint[2][256] memory Shamir8
    ) internal  returns (bool) {
     uint[2] memory Q;//extract Q from Shamir8
     
     if (rs[0] == 0 || rs[0] >= n || rs[1] == 0) {
            return false;
        }
        if (!isOnCurve(Q[0], Q[1])) {
            return false;
        }
  	
      

        uint sInv = inverseMod(rs[1], n);
        uint scalar_u=mulmod(uint(message), sInv, n);
        uint scalar_v= mulmod(rs[0], sInv, n);
 		
        // without Optim
        
      
 	
 	uint x1;
        uint x2;
        uint y1;
        uint y2;
        
        /*
        (x1, y1) = multiplyScalar(gx, gy, scalar_u);
        (x2, y2) = multiplyScalar(Q[0], Q[1], scalar_v);
        //uint[3] memory PAff = addAndReturnProjectivePoint(x1, y1, x2, y2);
        
        console.log("res naive Aff mul1:", x1, y1);
        console.log("res naive Aff mul2:", x2, y2);
        */
        
        
       // (x1, y1) = ecZZ_mul(gx, gy, scalar_u);
       // (x2, y2) = ecZZ_mul(Q[0], Q[1], scalar_v);
        
        
       // console.log("res naive ZZ:", x1, y1);
       // console.log("res naive ZZ:", x2, y2);
	      
        //test_ecZZ_formulae();
     
        //Shamir 2 dimensions 
        //(x1, y1)=ecZZ_mulmuladd_S(gx, gy, Q[0], Q[1],scalar_u, scalar_v);
        //Shamir 8 dimensions
         (x1, y1)=ecZZ_mulmuladd_S8(scalar_u, scalar_v, Shamir8);
       
	//uint[3] memory P = ec_mulmuladd_W(gx, gy, Q[0], Q[1],scalar_u ,scalar_v );
 	//uint Px=NormalizedX(P[0], P[1], P[2]);
 	
        //return Px % n == rs[0];
        return true;
        } 
}