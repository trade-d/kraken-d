module trading.kraken;

import vibe.d;

///
struct BalanceResult
{
	///
	@optional string[string] result;

	///
	@optional Json error;
}

///
enum OrderStatus
{
	pending, // = order pending book entry
	open, // = open order
	closed, // = closed order
	canceled, // = order canceled
	expired, // = order expired
}

///
enum OrderSide
{
	buy,
	sell
}

unittest
{
	assert(to!string(OrderSide.buy) == "buy");
}

///
struct OrderDesc
{
	string pair;
	@byName OrderSide type;
	string ordertype;
	string price;
	string price2;
	string leverage;
	string order;
	@optional string close;
}

///
struct OrderInfo
{
	@optional int userref;
	float opentm;
	float starttm;
	float expiretm;
	@optional float closetm;
	string vol;
	string vol_exec;
	OrderDesc descr;
	string fee;
	string price;
	@optional string refid;
	string oflags;
	@byName OrderStatus status;
	string misc;
	@optional string reason;
	string cost;
}

///
struct QueryOrdersResult
{
	///
	@optional OrderInfo[string] result;

	///
	@optional Json error;
}

///
struct AddOrderResult
{
	///
	struct Result
	{
		///
		Json descr;
		///
		string[] txid;
	}

	///
	@optional Result result;

	///
	@optional Json error;
}

///
struct TickerInfo
{
	/// current (last trade)
	string[] c;
	/// bid price
	string[] b;
	/// ask price
	string[] a;
	/// low
	string[] l;
	/// high
	string[] h;
	/// volume
	string[2] v;
}

///
struct TickerResult
{
	///
	TickerInfo[string] result;
}

///
struct OrderBook
{
	///
	Json[] asks;
	///
	Json[] bids;
}

///
struct OrderBookResult
{
	///
	OrderBook[string] result;
}

///
interface KrakenAPI
{
	///
	TickerResult Ticker(string pair);

	///
	OrderBookResult OrderBook(string pair);

	///
	BalanceResult Balance();

	///
	QueryOrdersResult QueryOrders(string txid);

	///
	AddOrderResult AddOrder(string pair, OrderSide type, string ordertype,
			string price, string volume);
}

///
final class Kraken : KrakenAPI
{
	static immutable API_URL = "https://api.kraken.com";

	private string key;
	private string secret;

	this(string key, string secret)
	{
		this.key = key;
		this.secret = secret;
	}

	TickerResult Ticker(string pair)
	{
		static immutable METHOD_URL = "/0/public/Ticker";

		Json params = Json.emptyObject;
		params["pair"] = pair;

		return request!TickerResult(METHOD_URL, params);
	}

	unittest
	{
		auto api = new Kraken("", "");
		auto res = api.Ticker("XRPUSD");
		assert(res.result.length > 0);
	}

	OrderBookResult OrderBook(string pair)
	{
		static immutable METHOD_URL = "/0/public/Depth";

		Json params = Json.emptyObject;
		params["pair"] = pair;

		return request!OrderBookResult(METHOD_URL, params);
	}

	BalanceResult Balance()
	{
		static immutable METHOD_URL = "/0/private/Balance";

		return request!BalanceResult(METHOD_URL);
	}

	QueryOrdersResult QueryOrders(string txid)
	{
		static immutable METHOD_URL = "/0/private/QueryOrders";

		Json params = Json.emptyObject;
		params["txid"] = txid;

		return request!QueryOrdersResult(METHOD_URL, params);
	}

	AddOrderResult AddOrder(string pair, OrderSide type, string ordertype,
			string price, string volume)
	{
		static immutable METHOD_URL = "/0/private/AddOrder";

		Json params = Json.emptyObject;
		params["pair"] = pair;
		params["type"] = to!string(type);
		params["ordertype"] = ordertype;
		params["volume"] = volume;
		params["trading_agreement"] = "agree";
		if (price.length > 0)
			params["price"] = price;

		return request!AddOrderResult(METHOD_URL, params);
	}

	private auto request(T)(string path, Json postData = Json.emptyObject)
	{
		import std.digest.sha : sha256Of, SHA512;
		import std.conv : to;
		import std.base64 : Base64;
		import std.digest.hmac : hmac;

		auto nonce = Clock.currStdTime();

		postData["nonce"] = nonce;

		auto res = requestHTTP(API_URL ~ path, (scope HTTPClientRequest req) {

			string payload = postData.toString;

			auto nonceAndData = nonce.to!string ~ payload;

			//logInfo("payload: %s",payload);

			auto signature = (path.representation ~ sha256Of(nonceAndData)).hmac!SHA512(
				Base64.decode(secret));

			req.method = HTTPMethod.POST;
			req.headers["API-Key"] = key;
			req.headers["API-Sign"] = Base64.encode(signature);
			req.headers["Content-Type"] = "application/json";
			req.headers["Content-Length"] = payload.length.to!string;

			req.bodyWriter.write(payload);
		});
		scope (exit)
		{
			res.dropBody();
		}

		if (res.statusCode == 200)
		{
			auto json = res.readJson();

			//logInfo("Response: %s", json);

			return deserializeJson!T(json);
		}
		else
		{
			logDebug("API Error: %s", res.bodyReader.readAllUTF8());
			logError("API Error Code: %s", res.statusCode);
			throw new Exception("API Error");
		}
	}
}
