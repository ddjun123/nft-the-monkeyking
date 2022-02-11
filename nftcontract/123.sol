// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./tmk2.sol";



contract Auction is TheMonkeyKing{
    using Counters for Counters.Counter;
    Counters.Counter private nftId;
    uint public price;
    uint public startTime;
    uint public endTime;
    uint public mintAmount;
    uint public firstSaleTokenId;
    bool userMintPausable=true;
    address public marketContractsAddress;
    /*mapping(uint=>string) public addressTracker;
    mapping(uint=>string) public statusTracker;*/

    /*modifier nftlimit(){
        require(currentNumberNft>=nftId._value,"the number of nfts has reached 20000.");
        _;
    }*/
    
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

    event teamMintNft(uint a,uint b);
    event startpublicsale(uint a,uint b);
    event _publicsale(address a,uint c);
    event _usermint(address a,uint b);
    event _withdrawfunds(uint a,address b,address c,address d);

    constructor(){
        endTime=block.timestamp;
        /*currentNumberNft=9;*/
        /*startTime = block.timestamp;
        endTime = block.timestamp+1 hours;*/
    }

    function userMintPause()external onlyOwner{
        userMintPausable=!userMintPausable;
    }

    function startPublicSale(uint time,uint salePrice)external onlyOwner{
        endTime=block.timestamp+time;
        price=salePrice;
        emit startpublicsale(endTime,price);
    }

    function teamMint(string[] memory nftUriList/*,uint mintNumber*/) external onlyOwner{
        mintAmount=nftUriList.length;
        firstSaleTokenId=nftId._value;
        for(uint i=0;i<nftUriList.length;i++){
            _safeMint(address(this),nftId._value);
            _setTokenURI(nftId._value,nftUriList[i]);
            nftId.increment();
        }
        emit teamMintNft(mintAmount,firstSaleTokenId);
    }

    function publicSale()external payable isOngoing() checkEther() {
        require(mintAmount!=0,"public sell is closed");
        _transfer(address(this),msg.sender,firstSaleTokenId);
        mintAmount--;
        firstSaleTokenId++;
        emit _publicsale(msg.sender,firstSaleTokenId-1);
    }

    function userMint(string memory nftUriData)external{
        require(userMintPausable,"userMint function has been closed");
        _safeMint(msg.sender,nftId._value);
        _setTokenURI(nftId._value,nftUriData);
        /*statusTracker[nftId._value]=0;*/
        nftId.increment();
        emit _usermint(msg.sender,nftId._value-1);
    }

    function withdraw(address payable ironbank,address payable marketing,address payable team)external notOngoing onlyOwner{
        emit _withdrawfunds(address(this).balance,ironbank,marketing,team);
        (bool success,)=ironbank.call{value:address(this).balance/100*85}("wagmi");
        require(success,"ironbank wrong");
        (bool success1,)=marketing.call{value:address(this).balance/100*66}("wagmi");
        require(success1,"marketing wrong");
        (bool success2,)=team.call{value:address(this).balance}("wagmi");
        require(success2,"team wrong");
    }

    function marketTransfer(address from,address to,uint productId) external{
        require(msg.sender==marketContractsAddress,"caller is not market contract address");
        _transfer(from,to,productId);

    }

    function setMarketContractAddress(address market) external onlyOwner{
        marketContractsAddress=market;
    }

    /*function teamMint(string[] memory nftList,uint mintNumber) external onlyOwner{
        for(uint i=0;i<nftList.length;i++){
        .push(nftList[i]);
        }
        currentNumberNft+=mintNumber;
    }*/
    
    receive ()external payable{

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

contract trade is TheMonkeyKing{
    
    uint private tax=90;
    Auction public auction;
    /*address payable addr;*/
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

    constructor(address payable addrs){
        auction=Auction(addrs);
    }

    /*function setNftMarketAddress(address payable addrs) external onlyOwner{
        auction=Auction(addrs);
    }*/

    function setTax(uint a)external onlyOwner{
        tax=a;
    }

    function marketPausable() external onlyOwner{
        marketPauseStatus=!marketPauseStatus;
    }


    function transferToMarket(uint tokenId,uint price)external {
        require(marketPauseStatus,"transferToMarket funtion has been closed");
        //require(auction.ownerOf(tokenId)==msg.sender,"you don't have this nft token");
        bidPrice[tokenId]=price;
        require(bidPrice[tokenId]!=0,"price cannot be 0");
        sellerAddress[tokenId]=msg.sender;
        auction.marketTransfer(msg.sender,address(this),tokenId);
        emit _nftisselling(msg.sender,price);
    }

    function makedeal(uint tokenId)external payable bidPriceCheck(tokenId) tokenPrice(tokenId) sellerAddressCheck(tokenId){
        uint bid=bidPrice[tokenId];
        address sellAddress=sellerAddress[tokenId];
        bidPrice[tokenId]=0;
        sellerAddress[tokenId]=address(0);
        /*genzongbianliangfuzhi*/
        auction.marketTransfer(address(this),msg.sender,tokenId);
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

    /*function userWithDraw(uint tokenId)external bidPriceCheck(tokenId){
        uint amount=bidPrice[tokenId];
        bidPrice[tokenId]=0;
        (bool success1,)=addr.call{value:amount/100*(100-tax)}("");
        require(success1,"contract withdrawal falied");
        (bool success,)=payable(msg.sender).call{value:amount/100*tax}("");
        require(success,"user withdrawal failed");
    }*/

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4){
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }   
}
