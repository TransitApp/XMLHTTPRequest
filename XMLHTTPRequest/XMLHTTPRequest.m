#import "XMLHTTPRequest.h"


@implementation XMLHttpRequest {
    NSURLSession *_urlSession;
    NSString *_httpMethod;
    NSURL *_url;
    bool _async;
    NSMutableDictionary *_requestHeaders;
    NSDictionary *_responseHeaders;
    NSMutableDictionary<NSString *, JSValue *> *_eventListeners;
};

@synthesize responseText;
@synthesize onreadystatechange;
@synthesize readyState;
@synthesize onload;
@synthesize onerror;
@synthesize status;

static NSString * const kEventListenerErrorType = @"error";

- (instancetype)init {
    return [self initWithURLSession:[NSURLSession sharedSession]];
}


- (instancetype)initWithURLSession:(NSURLSession *)urlSession {
    if (self = [super init]) {
        _urlSession = urlSession;
        self.readyState = @(XMLHttpRequestUNSENT);
        _requestHeaders = [NSMutableDictionary new];
        _eventListeners = [NSMutableDictionary new];
    }
    return self;
}

- (void)addEventListener:(NSString *)type :(JSValue *)listener :(BOOL)capture {
     [_eventListeners setObject:listener forKey:type];
}

- (void)extend:(id)jsContext {
    NSArray *xmlHttpRequestsTags = @[@"XMLHTTPRequest", @"XMLHttpRequest"];
    
    for (NSString *tag in xmlHttpRequestsTags) {
        // Simulate the constructor.
        jsContext[tag] = ^{
            return self;
        };

        jsContext[tag][@"UNSENT"] = @(XMLHttpRequestUNSENT);
        jsContext[tag][@"OPENED"] = @(XMLHTTPRequestOPENED);
        jsContext[tag][@"LOADING"] = @(XMLHTTPRequestLOADING);
        jsContext[tag][@"HEADERS"] = @(XMLHTTPRequestHEADERS);
        jsContext[tag][@"DONE"] = @(XMLHTTPRequestDONE);
    }
}

- (void)open:(NSString *)httpMethod :(NSString *)url :(bool)async {
    // TODO should throw an error if called with wrong arguments
    _httpMethod = httpMethod;
    _url = [NSURL URLWithString:url];
    _async = async;
    self.readyState = @(XMLHTTPRequestOPENED);
}

- (void)send:(id)data {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_url];
    for (NSString *name in _requestHeaders) {
        [request setValue:_requestHeaders[name] forHTTPHeaderField:name];
    }
    if ([data isKindOfClass:[NSString class]]) {
        request.HTTPBody = [((NSString *) data) dataUsingEncoding:NSUTF8StringEncoding];
    }
    [request setHTTPMethod:_httpMethod];

    __block __weak XMLHttpRequest *weakSelf = self;
    __block __weak NSMutableDictionary<NSString *, JSValue *> *weakEventListeners = _eventListeners;

    id completionHandler = ^(NSData *receivedData, NSURLResponse *response, NSError *error) {
        if (error) {
            for (NSString *type in [weakEventListeners allKeys]) {
                if ([type isEqualToString:kEventListenerErrorType]) {
                    JSValue *function = [weakEventListeners objectForKey:type];
                    if (function) {
                        [function callWithArguments:@[[error localizedDescription]]];
                    }
                }
            }
        }
        else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
            weakSelf.readyState = @(XMLHTTPRequestDONE); // TODO
            weakSelf.status = @(httpResponse.statusCode);
            weakSelf.responseText = [[NSString alloc] initWithData:receivedData
                                                      encoding:NSUTF8StringEncoding];
            [weakSelf setAllResponseHeaders:[httpResponse allHeaderFields]];
            if (weakSelf.onreadystatechange != nil) {
                [weakSelf.onreadystatechange callWithArguments:@[]];
            }
        }
    };
    NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:request
                                                completionHandler:completionHandler];
    [task resume];
}

- (void)setRequestHeader:(NSString *)name :(NSString *)value {
    _requestHeaders[name] = value;
}

- (NSString *)getAllResponseHeaders {
    NSMutableString *responseHeaders = [NSMutableString new];
    for (NSString *key in _responseHeaders) {
        [responseHeaders appendString:key];
        [responseHeaders appendString:@": "];
        [responseHeaders appendString:_responseHeaders[key]];
        [responseHeaders appendString:@"\n"];
    }
    return responseHeaders;
}

- (NSString *)getReponseHeader:(NSString *)name {
    return _responseHeaders[name];
}

- (void)setAllResponseHeaders:(NSDictionary *)responseHeaders {
    _responseHeaders = responseHeaders;
}

@end
