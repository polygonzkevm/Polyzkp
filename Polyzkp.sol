// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./ECDSA.sol";
import "./TransferHelper.sol";
import "./Address.sol";
import "./SafeMath.sol";


contract Polyzkp is Ownable {
    using SafeMath for uint256;

    address public walletFee;
    address public walletWithdraw;
    address public walletNode;
    address public walletTicket;
    address public walletPledge;

    uint public fee;
    uint private pointMax = 10 ** 8;

    mapping(address => mapping(address => uint)) public extractAmount;

    // 签名验证地址
	address private signer;

    // 禁用的证明
	mapping(bytes => bool) public expired;
    

    event Setting(
        address walletFee,
        address walletWithdraw,
        address walletNode,
        address walletTicket,
        address walletPledge,
        uint fee
    );

    event Entry(
        uint pid,
        uint[] field,
        address player,
        uint signType,
        address token,
        uint amount,
        uint time,
		bytes signature
    );

    event Expend(
        uint pledgeId,
        address player,
        address token,
        uint amount,
        uint fee,
        uint time,
		bytes signature
    );

    constructor(
        address _walletFee,
        address _walletWithdraw,
        address _walletNode,
        address _walletTicket,
        address _walletPledge,
        address _signer,
        uint _fee
    ) {
        _verifySign(_signer);
        _setting(_walletFee,_walletWithdraw,_walletNode,_walletTicket,_walletPledge,_fee);
    }

    receive() external payable {}
    fallback() external payable {}


    function hashMsg(
        uint pledgeId,
        uint signType,
		address token,
		uint amount,
		uint deadline
	) internal view returns (bytes32 msghash) {
		return	keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(pledgeId,block.chainid,signType,msg.sender,token,amount,deadline))
            )
        );
	}



    


    function _trust(
        uint pledgeId,
        uint signType,
		address token,
		uint amount,
		uint deadline,
        bytes memory signature
    ) private {
        require(!expired[signature],"Polyzkp::certificate expired");
        address prove = ECDSA.recover(hashMsg(pledgeId,signType,token,amount,deadline), signature);
        require(signer == prove,"Polyzkp::invalid certificate");	
        expired[signature] = true;
    }

    function _receive(
        uint signType,
        address token,
		uint amount
    ) private {
        address to;
        if(signType == 1) {
            // 节点入金
            to = walletNode;
        }else if(signType == 2) {
            // 门票入金
            to = walletTicket;
        }else if(signType == 3) {
            // 质押入金
            to = walletPledge;
        }
        if(token == address(0)) {
			require(msg.value == amount,"Polyzkp::input eth is not accurate");
            Address.sendValue(payable(to),msg.value);
		}else {
            TransferHelper.safeTransferFrom(token,msg.sender,to,amount);
		}
    }

    
    function Invest(
        uint pid,
        uint[] memory field,
        uint signType,
        address token,
        uint amount,
        uint deadline,
		bytes memory signature
    ) public payable {
        _trust(0,signType,token,amount,deadline,signature);
        _receive(signType,token,amount);

        emit Entry(pid,field,msg.sender,signType,token,amount,block.timestamp,signature);
        require(block.timestamp < deadline,"Polyzkp::Order Expiration");
    }

    function _expend(
        uint pledgeId,
        uint signType,
        address token,
        uint amount,
        bytes memory signature
    ) private {
        uint realAmount;
        uint feeAmount;
        if(signType == 4) {
            realAmount = amount;
            feeAmount = 0;
        }else if(signType == 5) {
            realAmount = pointMax.sub(fee).mul(amount).div(pointMax);
            feeAmount = amount.sub(realAmount);
        }
        // 记录提取量
        extractAmount[msg.sender][token] += amount;

        if(token == address(0)) {
            Address.sendValue(payable(msg.sender),realAmount);
            if(feeAmount > 0) {
                Address.sendValue(payable(walletFee),feeAmount);
            }
		}else {
            TransferHelper.safeTransferFrom(token,walletWithdraw,msg.sender,realAmount);
            if(feeAmount > 0) {
                TransferHelper.safeTransferFrom(token,walletWithdraw,walletFee,feeAmount);
            }
		}


        
        emit Expend(pledgeId,msg.sender,token,amount,feeAmount,block.timestamp,signature);
    }

    function Withdrawal(
        uint pledgeId,
        uint signType,
        address token,
        uint amount,
        uint deadline,
		bytes memory signature
    ) public {
        _trust(pledgeId,signType,token,amount,deadline,signature);
        _expend(pledgeId,signType,token,amount,signature);
        require(block.timestamp < deadline,"Polyzkp::Order Expiration");
    }

    

    function setting(
        address _walletFee,
        address _walletWithdraw,
        address _walletNode,
        address _walletTicket,
        address _walletPledge,
        uint _fee
    ) public onlyOwner {
        _setting(_walletFee,_walletWithdraw,_walletNode,_walletTicket,_walletPledge,_fee);
    }

    function _setting(
        address _walletFee,
        address _walletWithdraw,
        address _walletNode,
        address _walletTicket,
        address _walletPledge,
        uint _fee
    ) private {
        walletFee = _walletFee;
        walletWithdraw = _walletWithdraw;
        walletNode = _walletNode;
        walletTicket = _walletTicket;
        walletPledge = _walletPledge;
        fee = _fee;

        emit Setting(walletFee,walletWithdraw,walletNode,walletTicket,walletPledge,fee);
    }

    function verifySign(
		address _signer
	) public onlyOwner {
		_verifySign(_signer);
	}

	function _verifySign(
		address _signer
	) private {
		require(_signer != address(0),"Polyzkp::invalid signing address");
		signer = _signer;
	}
}
