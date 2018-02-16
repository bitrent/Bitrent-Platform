pragma solidity ^0.4.18;

import './UnityToken.sol';
import './base/Ownable.sol';
import './base/PermissionManager.sol';
import './Observer.sol';
import './base/BuildingStatus.sol';

/**
 * @title Building Object contract.
 * @author Vladimir Kovalchuk
 */
contract Object is Ownable, BuildingStatus {

    /* Name of an object */
    string public name;

    /* Gross building area */
    uint32 public gba;
    
    /* Gress sale area */
    uint32 public gla; 
    
    /* Parking space */
    uint32 public parking;
    
    /* Type of the building */
    enum unitEnum {appartment, residential}

    unitEnum public unit;
    
    /* Developer of an object */ 
    string public developer;
    
    /* Leed */
    string public leed;
    
    /* Location of an object */
    string public location;

    /* start date of a project */
    uint public constructionStart;

    /* end of construction of an object */ 
    uint public constructionEnd;
    // unt sqm
    uint public untsqm;

    /* report of completion */ 
    string public report;

    struct Contribution {
        uint amountETH;
        uint amountUSD;
        uint amountUNT;
        bool withdrawed;
        bool refunded;
    }

    event ConstructionDateChanged(uint constructStart , uint constructEnd);
    event PropertyChanged(uint32  gba, uint32  gla, uint32 parking, unitEnum unit, string developer,
    string leed, string location, uint constructionStart, uint constructionEnd);
   
    event HoldChanged(address newHold);
    event ObserverChanged(address newObserver);
    event CrowdsaleChanged(address newCrowdsale);
    
    /* ERC223 Unity token */
    UnityToken public token;

    /* Crowdsale contract */
    address public crowdsale;

    /* Observer contract  */
    Observer public observer;

    /* Hold contract */
    address public hold;

    /* Permission manager contract */
    PermissionManager public permissionManager;

    

    modifier onlyPermitted() {
        require(permissionManager.isPermitted(msg.sender) || msg.sender == owner);
        _;
    }
    modifier onlyObserver() {
        require(msg.sender == address(observer) || msg.sender == address(owner));
        _;
    }

    modifier onlyOwnerOrThis() {
        require(msg.sender == address(owner) || msg.sender == address(this));
        _;
    }

    event Completed(string report);
    
    /* Constructor of an object */ 
    function Object(string iName, uint32 iGBA, uint32 iGSA, uint32 iParking, unitEnum iUnit, 
        string iDeveloper, string iLeed, string iLocation, uint iStartDate, uint iEndDate, uint UNTSQM,
        address iToken, address iCrowdsale, address iObserver, address iHold, address pManager) public {
            name = iName;
            gba = iGBA;
            gla = iGSA;
            parking = iParking;
            unit = iUnit;
            developer = iDeveloper;
            leed = iLeed;
            location = iLocation;
            untsqm = UNTSQM;
            constructionStart = iStartDate;
            constructionEnd = iEndDate;

            token = UnityToken(iToken);
            crowdsale = iCrowdsale;
            observer = Observer(iObserver);
            hold = iHold;
            permissionManager = PermissionManager(pManager);
    }

    function setPermissionManager(address _permadr) public onlyOwner {
        require(_permadr != 0x0);
        permissionManager = PermissionManager(_permadr);
    }
    
    /*
     * Public setters area 
     */
    function setGBA(uint32 newGBA) public onlyOwnerOrThis notCompleted {
        gba = newGBA;
        PropertyChanged(gba, gla, parking, unit, developer, leed, location, constructionStart, constructionEnd);
    }

    function setGLA(uint32 newGLA) public onlyOwnerOrThis notCompleted {
        gla = newGLA;
        PropertyChanged(gba, gla, parking, unit, developer, leed, location, constructionStart, constructionEnd);
    }

    function setParking(uint32 newParking) public onlyOwnerOrThis notCompleted {
        parking = newParking;
        PropertyChanged(gba, gla, parking, unit, developer, leed, location, constructionStart, constructionEnd);
    }

    function setUnit(unitEnum newUnit) public onlyOwnerOrThis notCompleted {
      unit = newUnit;
      PropertyChanged(gba, gla, parking, unit, developer, leed, location, constructionStart, constructionEnd);
    }

    function setDeveloper(string newDeveloper) public onlyOwnerOrThis notCompleted {
        developer = newDeveloper;
        PropertyChanged(gba, gla, parking, unit, developer, leed, location, constructionStart, constructionEnd);
    }

    function setLeed(string newLeed) public onlyOwnerOrThis notCompleted {
        leed = newLeed;
        PropertyChanged(gba, gla, parking, unit, developer, leed, location, constructionStart, constructionEnd);
    }

    function setLocation(string newLocation) public onlyOwnerOrThis notCompleted {
        location = newLocation;
        PropertyChanged(gba, gla, parking, unit, developer, leed, location, constructionStart, constructionEnd);
    }

    function setStartDate(uint newStartDate) public onlyOwnerOrThis notCompleted {
        constructionStart = newStartDate;
        PropertyChanged(gba, gla, parking, unit, developer, leed, location, constructionStart, constructionEnd);
    }

    function setEndDate(uint newEndDate) public onlyOwnerOrThis notCompleted {
        constructionEnd = newEndDate;
        PropertyChanged(gba, gla, parking, unit, developer, leed, location, constructionStart, constructionEnd);
    }


    function setUntsqm(uint _untsqm) public onlyObserver notCompleted {
        untsqm = _untsqm;
        PropertyChanged(gba, gla, parking, unit, developer, leed, location, constructionStart, constructionEnd);
    }

    function changeStage(uint8 stage) public onlyObserver {
        if (stage==1) status = statusEnum.stage1;
        if (stage==2) status = statusEnum.stage2;
        if (stage==3) status = statusEnum.stage3;
        if (stage==4) status = statusEnum.stage4;
        if (stage==5) status = statusEnum.stage5;
    }

    function setObserver(address _observer) public onlyOwner {
      require(_observer != 0x0);
        observer = Observer(_observer);
        ObserverChanged(_observer);
    }

    function setToken(address _token) public onlyOwner {
      require(_token != 0x0);
        token = UnityToken(_token);
    }

    function setHold(address _hold) public onlyOwner {
      require(_hold != 0x0);
        hold = _hold;
        HoldChanged(_hold);
    }

    function setCrowdsale(address _crowdsale) public onlyOwner {
      require(_crowdsale != 0x0);
      crowdsale = _crowdsale;
        CrowdsaleChanged(_crowdsale);
    }

    function getTotalSupply() public view returns (uint) {
        return token.getTotalSupply();
    }

    function getUNTSQM() public view returns (uint) {
        return untsqm;
    } 

    function setProperty(string property, string typeArg, uint intVal, string strVal) public onlyObserver {
        string memory set = "set";
        string memory s = "(";
        string memory s2 = ")";
        bytes memory _ba = bytes(set);
        bytes memory _bb = bytes(property);
        bytes memory _t = bytes(typeArg);
        bytes memory _s = bytes(s);
        bytes memory _s2 = bytes(s2);
        string memory ab = new string(_ba.length + _bb.length + 1 + _t.length + 1);
        bytes memory babcde = bytes(ab);
        uint k = 0;

        for (uint i = 0; i < _ba.length; i++) {
            babcde[k++] = _ba[i];
        }
        for (i = 0; i < _bb.length; i++) {
            babcde[k++] = _bb[i];
        }
        babcde[k++] = _s[0];

        for (i = 0; i < _t.length; i++) {
            babcde[k++] = _t[i];
        }

        babcde[k++] = _s2[0];
        if (intVal==0) {
          assert(this.call(bytes4(keccak256(string(babcde))), strVal));
        } else {
          assert(this.call(bytes4(keccak256(string(babcde))), intVal));
        }
    }
    
    function completeStatus(string newReport) public onlyOwner notCompleted {
        status = statusEnum.completed;
        report = newReport;
        Completed(report);
    }


}