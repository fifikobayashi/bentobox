/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import { Contract, ContractFactory, Overrides } from "@ethersproject/contracts";

import type { SushiBarMock } from "../SushiBarMock";

export class SushiBarMock__factory extends ContractFactory {
  constructor(signer?: Signer) {
    super(_abi, _bytecode, signer);
  }

  deploy(_sushi: string, overrides?: Overrides): Promise<SushiBarMock> {
    return super.deploy(_sushi, overrides || {}) as Promise<SushiBarMock>;
  }
  getDeployTransaction(
    _sushi: string,
    overrides?: Overrides
  ): TransactionRequest {
    return super.getDeployTransaction(_sushi, overrides || {});
  }
  attach(address: string): SushiBarMock {
    return super.attach(address) as SushiBarMock;
  }
  connect(signer: Signer): SushiBarMock__factory {
    return super.connect(signer) as SushiBarMock__factory;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): SushiBarMock {
    return new Contract(address, _abi, signerOrProvider) as SushiBarMock;
  }
}

const _abi = [
  {
    inputs: [
      {
        internalType: "contract ERC20",
        name: "_sushi",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "_owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "_spender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "_value",
        type: "uint256",
      },
    ],
    name: "Approval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "_from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "_to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "_value",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    inputs: [],
    name: "DOMAIN_SEPARATOR",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "allowance",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "approve",
    outputs: [
      {
        internalType: "bool",
        name: "success",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "balanceOf",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_amount",
        type: "uint256",
      },
    ],
    name: "enter",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_share",
        type: "uint256",
      },
    ],
    name: "leave",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "name",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "nonces",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner_",
        type: "address",
      },
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "deadline",
        type: "uint256",
      },
      {
        internalType: "uint8",
        name: "v",
        type: "uint8",
      },
      {
        internalType: "bytes32",
        name: "r",
        type: "bytes32",
      },
      {
        internalType: "bytes32",
        name: "s",
        type: "bytes32",
      },
    ],
    name: "permit",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "sushi",
    outputs: [
      {
        internalType: "contract ERC20",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "symbol",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalSupply",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "transfer",
    outputs: [
      {
        internalType: "bool",
        name: "success",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "transferFrom",
    outputs: [
      {
        internalType: "bool",
        name: "success",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b506040516110db3803806110db8339818101604052602081101561003357600080fd5b5051600380546001600160a01b0319166001600160a01b03909216919091179055611078806100636000396000f3fe608060405234801561001057600080fd5b50600436106100ea5760003560e01c806370a082311161008c578063a59f3e0c11610066578063a59f3e0c1461029b578063a9059cbb146102b8578063d505accf146102e4578063dd62ed3e14610335576100ea565b806370a08231146102475780637ecebe001461026d57806395d89b4114610293576100ea565b806318160ddd116100c857806318160ddd146101d057806323b872dd146101ea5780633644e5151461022057806367dfd4c914610228576100ea565b806306fdde03146100ef578063095ea7b31461016c5780630a087903146101ac575b600080fd5b6100f7610363565b6040805160208082528351818301528351919283929083019185019080838360005b83811015610131578181015183820152602001610119565b50505050905090810190601f16801561015e5780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b6101986004803603604081101561018257600080fd5b506001600160a01b038135169060200135610387565b604080519115158252519081900360200190f35b6101b46103ee565b604080516001600160a01b039092168252519081900360200190f35b6101d86103fd565b60408051918252519081900360200190f35b6101986004803603606081101561020057600080fd5b506001600160a01b03813581169160208101359091169060400135610403565b6101d8610699565b6102456004803603602081101561023e57600080fd5b50356106f0565b005b6101d86004803603602081101561025d57600080fd5b50356001600160a01b0316610817565b6101d86004803603602081101561028357600080fd5b50356001600160a01b0316610829565b6100f761083b565b610245600480360360208110156102b157600080fd5b503561085d565b610198600480360360408110156102ce57600080fd5b506001600160a01b038135169060200135610976565b610245600480360360e08110156102fa57600080fd5b506001600160a01b03813581169160208101359091169060408101359060608101359060ff6080820135169060a08101359060c00135610aff565b6101d86004803603604081101561034b57600080fd5b506001600160a01b0381358116916020013516610df7565b6040518060400160405280600881526020016729bab9b434a130b960c11b81525081565b3360008181526001602090815260408083206001600160a01b038716808552908352818420869055815186815291519394909390927f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925928290030190a35060015b92915050565b6003546001600160a01b031681565b60045481565b60006001600160a01b038316610459576040805162461bcd60e51b815260206004820152601660248201527545524332303a206e6f207a65726f206164647265737360501b604482015290519081900360640190fd5b6001600160a01b0384166000908152602081905260409020548211156104bf576040805162461bcd60e51b815260206004820152601660248201527545524332303a2062616c616e636520746f6f206c6f7760501b604482015290519081900360640190fd5b6001600160a01b0384166000908152600160209081526040808320338452909152902054821115610537576040805162461bcd60e51b815260206004820152601860248201527f45524332303a20616c6c6f77616e636520746f6f206c6f770000000000000000604482015290519081900360640190fd5b6001600160a01b03831660009081526020819052604090205482810110156105a1576040805162461bcd60e51b8152602060048201526018602482015277115490cc8c0e881bdd995c999b1bddc819195d1958dd195960421b604482015290519081900360640190fd5b6001600160a01b03841660009081526020818152604080832080548690039055600182528083203384529091529020546000198114610637576001600160a01b0385166000908152600160209081526040808320338085529083529281902086850390558051868152905183927f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925928290030190a35b6001600160a01b03808516600081815260208181526040918290208054880190558151878152915192938916927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9281900390910190a3506001949350505050565b604080517f47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218602080830191909152468284015230606080840191909152835180840390910181526080909201909252805191012090565b60048054600354604080516370a0823160e01b81523094810194909452519192600092849261077e926001600160a01b03909116916370a0823191602480820192602092909190829003018186803b15801561074b57600080fd5b505afa15801561075f573d6000803e3d6000fd5b505050506040513d602081101561077557600080fd5b50518590610e14565b8161078557fe5b0490506107923384610e80565b6003546040805163a9059cbb60e01b81523360048201526024810184905290516001600160a01b039092169163a9059cbb916044808201926020929091908290030181600087803b1580156107e657600080fd5b505af11580156107fa573d6000803e3d6000fd5b505050506040513d602081101561081057600080fd5b5050505050565b60006020819052908152604090205481565b60026020526000908152604090205481565b6040518060400160405280600681526020016578537573686960d01b81525081565b600354604080516370a0823160e01b815230600482015290516000926001600160a01b0316916370a08231916024808301926020929190829003018186803b1580156108a857600080fd5b505afa1580156108bc573d6000803e3d6000fd5b505050506040513d60208110156108d257600080fd5b50516004549091508015806108e5575081155b156108f9576108f43384610f11565b61091c565b6000826109068584610e14565b8161090d57fe5b04905061091a3382610f11565b505b600354604080516323b872dd60e01b81523360048201523060248201526044810186905290516001600160a01b03909216916323b872dd916064808201926020929091908290030181600087803b1580156107e657600080fd5b60006001600160a01b0383166109cc576040805162461bcd60e51b815260206004820152601660248201527545524332303a206e6f207a65726f206164647265737360501b604482015290519081900360640190fd5b33600090815260208190526040902054821115610a29576040805162461bcd60e51b815260206004820152601660248201527545524332303a2062616c616e636520746f6f206c6f7760501b604482015290519081900360640190fd5b6001600160a01b0383166000908152602081905260409020548281011015610a93576040805162461bcd60e51b8152602060048201526018602482015277115490cc8c0e881bdd995c999b1bddc819195d1958dd195960421b604482015290519081900360640190fd5b33600081815260208181526040808320805487900390556001600160a01b03871680845292819020805487019055805186815290519293927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef929181900390910190a350600192915050565b6001600160a01b038716610b5a576040805162461bcd60e51b815260206004820152601860248201527f45524332303a204f776e65722063616e6e6f7420626520300000000000000000604482015290519081900360640190fd5b834210610b9f576040805162461bcd60e51b815260206004820152600e60248201526d115490cc8c0e88115e1c1a5c995960921b604482015290519081900360640190fd5b600060405180604001604052806002815260200161190160f01b815250610bc4610699565b6001600160a01b03808b1660008181526002602090815260409182902080546001810190915582517f6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c98184015280840194909452938d166060840152608083018c905260a083019390935260c08083018b90528151808403909101815260e0830190915280519083012084519092610100909201918291908601908083835b60208310610c825780518252601f199092019160209182019101610c63565b51815160209384036101000a6000190180199092169116179052920194855250838101929092525060408051808403830181528184018083528151918401919091206000918290526060850180845281905260ff8a16608086015260a0850189905260c085018890529151919550935060019260e08082019392601f1981019281900390910190855afa158015610d1d573d6000803e3d6000fd5b505050602060405103519050886001600160a01b0316816001600160a01b031614610d8f576040805162461bcd60e51b815260206004820152601860248201527f45524332303a20496e76616c6964205369676e61747572650000000000000000604482015290519081900360640190fd5b6001600160a01b03808a166000818152600160209081526040808320948d16808452948252918290208b905581518b815291517f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b9259281900390910190a3505050505050505050565b600160209081526000928352604080842090915290825290205481565b6000811580610e2f57505080820282828281610e2c57fe5b04145b6103e8576040805162461bcd60e51b815260206004820152601860248201527f426f72696e674d6174683a204d756c204f766572666c6f770000000000000000604482015290519081900360640190fd5b6001600160a01b038216600090815260208190526040902054610ea39082610f9a565b6001600160a01b038316600090815260208190526040902055600454610ec99082610f9a565b6004556040805182815290516000916001600160a01b038516917fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9181900360200190a35050565b600454610f1e9082610fea565b6004556001600160a01b038216600090815260208190526040902054610f449082610fea565b6001600160a01b0383166000818152602081815260408083209490945583518581529351929391927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9281900390910190a35050565b808203828111156103e8576040805162461bcd60e51b8152602060048201526015602482015274426f72696e674d6174683a20556e646572666c6f7760581b604482015290519081900360640190fd5b818101818110156103e8576040805162461bcd60e51b815260206004820152601860248201527f426f72696e674d6174683a20416464204f766572666c6f770000000000000000604482015290519081900360640190fdfea264697066735822122010c062ab4e8ddeb5ae52c5f16bc275484d38e713c17b9d1e9089580659617ec164736f6c634300060c0033";
