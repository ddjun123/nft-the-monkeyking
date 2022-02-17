// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.2;

import "@openzeppelin/contracts@4.4.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.4.2/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.4.2/security/Pausable.sol";
import "@openzeppelin/contracts@4.4.2/access/Ownable.sol";
import "@openzeppelin/contracts@4.4.2/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@4.4.2/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";



contract TMKNFT is ERC721, ERC721URIStorage, Pausable, Ownable, ERC721Burnable{
    
    using Counters for Counters.Counter;
    Counters.Counter private nftId;
    uint public blindBoxAmount;
    uint public firstSaleTokenId;
    bool userMintPausable=true;
    address public marketContractsAddress;
    
    constructor() ERC721("TheMonkeyKing", "TMK") {}

    event teamMintNftTo(uint a,uint b,address _market);
    event _usermint(address a,uint b);
    event _withdrawfunds(uint a,address b,address c,address d);

    /*erc721 token function*/
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /*pause or unpause usermint function*/
    function userMintPause()external onlyOwner{
        userMintPausable=!userMintPausable;
    }

    /*team mint nft,the number is x,the first minted nft id is firstSaleTokenId*/
    function blindBoxMint(string[] memory nftUriList,address market) external onlyOwner{
        blindBoxAmount=nftUriList.length;
        firstSaleTokenId=nftId._value;
        for(uint i=0;i<nftUriList.length;i++){
            _safeMint(market,nftId._value);
            _setTokenURI(nftId._value,nftUriList[i]);
            nftId.increment();
        }
        emit teamMintNftTo(blindBoxAmount,firstSaleTokenId,market);
    }

    /*users can mint their own nft,this function can be closed.*/
    function userMint(string memory nftUriData)external{
        require(userMintPausable,"userMint function has been closed");
        _safeMint(msg.sender,nftId._value);
        _setTokenURI(nftId._value,nftUriData);
        nftId.increment();
        emit _usermint(msg.sender,nftId._value-1);
    }

    function withdraw(address payable ironbank,address payable marketing,address payable team)external onlyOwner{
        emit _withdrawfunds(address(this).balance,ironbank,marketing,team);
        (bool success,)=ironbank.call{value:address(this).balance/100*85}("wagmi");
        require(success,"ironbank wrong");
        (bool success1,)=marketing.call{value:address(this).balance/100*66}("wagmi");
        require(success1,"marketing wrong");
        (bool success2,)=team.call{value:address(this).balance}("wagmi");
        require(success2,"team wrong");
    }
    
    receive ()external payable{}

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4){
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }   
}

contract trade is Ownable{

    TMKNFT public tmknft;
    uint public tax;
    bool public marketPauseStatus=true;
    mapping(uint=>uint) public bidPrice;
    mapping(uint=>address) public sellerAddress;

    modifier tokenPrice(uint tokenId){
        require(bidPrice[tokenId]<=msg.value,"ether amount is not enough");
        _;
    }

    modifier sellerAddressCheck(uint tokenId){
        require(sellerAddress[tokenId]!=address(0),"Your nft is in your wallet or your nft never participates this market.addresscheck");
        _;
    }

    modifier bidPriceCheck(uint tokenId){
        require(bidPrice[tokenId]!=0,"Your nft is in your wallet or your nft never participates this market.bidpricecheck");
        _;
    }

    event _nftisselling(address a,uint b);
    event _nfthasbeensold(address a,uint b);
    event _withdrawfunds(uint a,address b,address c,address d);
    event _setPrice(address a,uint b,uint c);
    event _withdrawToken(address a,uint b);
    
    constructor(address payable addrs,uint _tax){
        tmknft=TMKNFT(addrs);
        tax=_tax;
    }

    //adjust the tax rate
    function setTax(uint a)external onlyOwner{
        tax=a;
    }


    function marketPausable() external onlyOwner{
        marketPauseStatus=!marketPauseStatus;
    }
    

    function transferToMarket(uint tokenId,uint price)external {
        require(marketPauseStatus,"transferToMarket funtion has been closed");
        //require(tmknft.ownerOf(tokenId)==msg.sender,"you don't have this nft token");
        bidPrice[tokenId]=price;
        require(bidPrice[tokenId]!=0,"price cannot be 0");
        sellerAddress[tokenId]=msg.sender;
        tmknft.safeTransferFrom(msg.sender,address(this),tokenId);
        emit _nftisselling(msg.sender,price);
    }

    function makedeal(uint tokenId)external payable bidPriceCheck(tokenId) tokenPrice(tokenId) sellerAddressCheck(tokenId){
        uint bid=bidPrice[tokenId];
        address sellAddress=sellerAddress[tokenId];
        bidPrice[tokenId]=0;
        sellerAddress[tokenId]=address(0);
        /*genzongbianliangfuzhi*/
        tmknft.safeTransferFrom(address(this),msg.sender,tokenId);
        (bool success,)=payable(sellAddress).call{value:bid/100*tax}("");
        require(success,"seller withdrawal failed,maybe seller is a contract");
        emit _nfthasbeensold(msg.sender,msg.value);
    }

    function withdrawFunds(address payable ironbank,address payable marketing,address payable team)external onlyOwner{
        emit _withdrawfunds(address(this).balance,ironbank,marketing,team);
        (bool success,)=ironbank.call{value:address(this).balance/100*85}("wagmi");
        require(success,"ironbank wrong");
        (bool success1,)=marketing.call{value:address(this).balance/100*66}("wagmi");
        require(success1,"marketing wrong");
        (bool success2,)=team.call{value:address(this).balance}("wagmi");
        require(success2,"team wrong");
    }

    function setPrice(uint tokenId,uint _price) external{
        require(address(0)!=sellerAddress[tokenId],"This token is not involved in this sale");
        require(msg.sender==sellerAddress[tokenId]," This token does not belong to you");
        bidPrice[tokenId]=_price;
        require(bidPrice[tokenId]!=0,"price cannot be 0");
        emit _setPrice(msg.sender,_price,tokenId);

    }

    function withdrawToken(uint tokenId)external{
        require(address(0)!=sellerAddress[tokenId],"This token is not involved in this sale");
        require(sellerAddress[tokenId]==msg.sender,"This token does not belong to you");
        tmknft.safeTransferFrom(address(this),msg.sender,tokenId);
        bidPrice[tokenId]=0;
        sellerAddress[tokenId]=address(0);
        emit _withdrawToken(msg.sender,tokenId);

    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4){
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }   
}


contract blindBoxAuction is Ownable,VRFConsumerBase{

    TMKNFT public tmknft;
    uint public price;
    uint public endTime;
    uint public fee;
    uint public randomResult;
    uint public blindBoxAmount;
    uint public counterNumber;
    bytes32 public keyHash;
    bytes32 public successId;
    address[] public buyerAddress;
    address[] public blindBoxResults;

    modifier isOngoing(){
        require(block.timestamp<endTime,"This official auction is closed.");
        _;
    }
    
    modifier notOngoing(){
        require(block.timestamp>=endTime,"This official auction is still open");
        _;
    }

    modifier checkEther(){
        require(msg.value>=price,"sorry,you need to pay more ether.");
        _;
    }

    constructor(address payable addrs,address _vrfCoordinator, address _link,bytes32 _keyHash,uint _fee) VRFConsumerBase(_vrfCoordinator, _link) {
        tmknft=TMKNFT(addrs);
        keyHash=_keyHash;
        fee=_fee;
    }

    event _startBlindBoxPublicSale(uint a,uint b);
    event _blindBoxPublicSale(address a,uint c);
    event _requestRandomNumber(bytes32 a);
    event _getRandomNumber(bytes32 id,uint randomNumber);
    event _saleHasEnded(string a);
    event _withdrawfunds(uint a,address b,address c,address d);

    function startBlindBoxPublicSale(uint time,uint salePrice)external onlyOwner{
        endTime=block.timestamp+time;
        price=salePrice;
        blindBoxAmount=tmknft.blindBoxAmount();
        counterNumber=tmknft.blindBoxAmount();
        emit _startBlindBoxPublicSale(endTime,price);
    }

    function blindBoxPublicSale()external payable isOngoing() checkEther() {
        require(blindBoxAmount!=0,"blind box public sale is closed");
        if(blindBoxAmount==1){
            require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract");
            successId=requestRandomness(keyHash,fee);
            emit _requestRandomNumber(successId);
        }
        blindBoxAmount--;
        buyerAddress.push(msg.sender);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override{
        require(requestId==successId,"requestId is wrong");
        randomResult=randomness;
        emit _getRandomNumber(requestId,randomness);
    }

    function generateMultipleRandomNumbers(uint _randomNumbers) internal view returns(uint[] memory _multipleRandomNumbers){
        uint _blindBoxAmount=tmknft.blindBoxAmount();
        _multipleRandomNumbers=new uint[](_blindBoxAmount-1);
        for(uint i=0;i<_blindBoxAmount-1;i++){
            _multipleRandomNumbers[i]=uint(keccak256(abi.encode(_randomNumbers,i)));
        }
        return _multipleRandomNumbers;

    }

    function generateBlindBox()external notOngoing() onlyOwner{
        address[] memory _buyerAddress=buyerAddress;
        address[] memory _blindBoxResults=new address[](_buyerAddress.length);
        uint[] memory _multipleRandomNumbers=generateMultipleRandomNumbers(randomResult);
        for(uint i=0;i<_multipleRandomNumbers.length;i++){
            _blindBoxResults[i]=_buyerAddress[_multipleRandomNumbers[i]%(_multipleRandomNumbers.length-i+1)];
            uint _index=_multipleRandomNumbers[i]%(_multipleRandomNumbers.length-i+1);
            address[] memory _BuyerAddress=new address[](_buyerAddress.length-1);
            for(uint a=0;a<_BuyerAddress.length;a++){
                if(a<_index){
                    _BuyerAddress[a]=_buyerAddress[a];
                }else{
                    _BuyerAddress[a]=_buyerAddress[a+1];
                }            
            }
            _buyerAddress=_BuyerAddress;            
        }
        _blindBoxResults[_blindBoxResults.length-1]=_buyerAddress[0];
        blindBoxResults=_blindBoxResults;
        
    }

    function getBlindBox(uint _index)external notOngoing() {
        require(blindBoxResults.length!=0,"blind boxes are not generated");
        require(blindBoxResults[_index]==msg.sender,"blind box is not belong to caller");
        delete blindBoxResults[_index];
        uint firstSaleTokenId=tmknft.firstSaleTokenId();
        tmknft.safeTransferFrom(address(this),msg.sender,firstSaleTokenId+_index);
        emit _blindBoxPublicSale(msg.sender,firstSaleTokenId+_index);
        counterNumber--;
        if(counterNumber==0){
            delete blindBoxResults;
            delete buyerAddress;
            emit _saleHasEnded("sale has ended");
        }
    }

    function reset() external onlyOwner{
        require(block.timestamp>endTime+7 days,"It's not time yet");
        delete blindBoxResults;
        delete buyerAddress;

    }

    /*function withdrawLink() external onlyOwner{
        LINK.transferFrom(address(this),msg.sender,LINK.balanceOf(address(this)));
    }*/

    function withdrawFunds(address payable ironbank,address payable marketing,address payable team)external onlyOwner{
        emit _withdrawfunds(address(this).balance,ironbank,marketing,team);
        (bool success,)=ironbank.call{value:address(this).balance/100*85}("wagmi");
        require(success,"ironbank wrong");
        (bool success1,)=marketing.call{value:address(this).balance/100*66}("wagmi");
        require(success1,"marketing wrong");
        (bool success2,)=team.call{value:address(this).balance}("wagmi");
        require(success2,"team wrong");
    }

    receive ()external payable{}

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4){
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }   

    
}