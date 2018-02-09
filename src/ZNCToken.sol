pragma solidity ^0.4.4;


contract owned {
    address public owner;

    function owned() public{
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}


contract ERC20Token {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract StandardToken is ERC20Token {

    function transfer(address _to, uint _value) public returns (bool success) {
        //Default assumes totalSupply can't be over max (2^256 - 1).
        //If your token leaves out totalSupply and can issue more tokens as time goes on, you need to check if it doesn't wrap.
        //Replace the if with this one instead.
        //if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        } else { return false; }
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool success) {
        //same as above. Replace this line with the following if you want to protect against wrapping uints.
        //if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        } else { return false; }
    }

    function balanceOf(address _owner) public constant  returns (uint balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public constant returns (uint remaining) {
      return allowed[_owner][_spender];
    }

    mapping (address => uint) balances;
    mapping (address => mapping (address => uint)) allowed;
    uint public _supply;

    function totalSupply() public constant returns (uint supply) {
    return _supply;
  }

}


contract ZNCToken is StandardToken,owned {
    uint256 public startTime;
    uint256 public presale_lock_day;
    uint256 public team_total_lock_day;
    string public name = "ZNC Token";
    string public symbol = "ZNC";
    string public version = "V0.1.0";
    uint public decimals = 12;


    mapping (address => uint) presale_IDs;
    uint public presale_count;

    address team_address;
    uint public team_lock_count ;
    uint public last_release_date ;
    uint public team_lock_epoch;
    uint public release_count_epoch;



    function ZNCToken(uint _totalSupply,uint256 _presale_lock_day,uint256 _team_total_lock_day,uint _team_lock_epoch) public{
        startTime = now;
        presale_lock_day = _presale_lock_day * 1 minutes;
        team_total_lock_day = _team_total_lock_day * 1 minutes;
        team_lock_epoch = _team_lock_epoch;

        _supply = _totalSupply * 10 ** uint256(decimals);  
        balances[msg.sender] = _supply ;
        team_lock_count = _supply * 15 / 100;
        owner = msg.sender;

        last_release_date = now;
        presale_count = 0;
        release_count_epoch = team_lock_count/(_team_total_lock_day/_team_lock_epoch);//10000, 24, 2


    }

    function transfer(address _to, uint _value) public returns (bool success) {

        require (_to != 0x0 && msg.sender != team_address );

        require (presale_IDs[msg.sender] == 0 || now > startTime + presale_lock_day  );

        //cannot transfer before presale finished!
        // require( presale_count * 100   >= 5 * _supply);
        require (balances[msg.sender] >= _value && _value > 0);

        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;
    }
    
    function presale(address _to, uint256 _value) public onlyOwner returns (bool success)   {
        require (presale_IDs[msg.sender] == 0 && _value > 0 && _to !=team_address);
        require (_to != 0x0);
        uint v = _value * 10 ** uint256(decimals);
        //!!require ((uint)((presale_count+v) * 100) <= 5 * _supply );
        require (balances[msg.sender] >= v && v > 0) ;
        balances[msg.sender] -= v;
        balances[_to] += v;
        presale_IDs [ _to ]  += v;
        presale_count += v;
        Transfer(msg.sender, _to, v);
        return true;

    }

    function frozen_team(address _to) public onlyOwner returns (bool success)   {

        require (team_address == 0 && balances[owner] == _supply);

        team_address = _to;
        
        uint v = team_lock_count;

        balances[msg.sender] -= v;
        balances[_to] += v;
        Transfer(msg.sender, _to, v);
        return true;
    }

    function release_team_coin(address _to) public onlyOwner returns (bool success)   {
        require (balances[team_address] > 0);
        require (now > last_release_date + team_lock_epoch * 1 minutes );
        
        uint epoch_release_count = (now - last_release_date)  / (team_lock_epoch * 1 minutes) * release_count_epoch;
       
        if(balances[team_address]>epoch_release_count){
            epoch_release_count = epoch_release_count;
        }else{
            epoch_release_count = balances[team_address];
        }
        
        balances[team_address] -= epoch_release_count;
        balances[_to] += epoch_release_count;
        last_release_date += epoch_release_count/release_count_epoch * (team_lock_epoch * 1 minutes);
        team_lock_count -= epoch_release_count;

        Transfer(team_address, _to, epoch_release_count);
        return true;
    }

}


