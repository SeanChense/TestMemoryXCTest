title: So you get memory leak in XCTest
date: 2017-10-21 13:54:00
---
## 0 致敬

我把标题命名为 So you get memory leak in XCTest 是致敬 [[objc explain]: So you crashed in objc_msgSend()](http://sealiesoftware.com/blog/archive/2008/09/22/objc_explain_So_you_crashed_in_objc_msgSend.html)

## 1 前言

自动化测试是我们正在做的技术需求，但是 bot 上的模拟器经常因为内存耗尽而提前终止运行。这意味着我们在自动化测试中遇到了内存泄漏！
为了提高 bot 的稳定性，必须找到内存泄漏的问题所在。

## 2 XCTest

自动化测试建立在 Apple 提供的 XCTest 这套框架体系之上，我们在一些开源库的基础上搭建了一套适合美团的函数式自动化测试框架。

	+ (void)setUp
	+ (void)tearDown

这两个类函数会在整个 XCTest 开始测试和测试完毕之后分别调用。

	- (void)setUp {
		[super setUp];
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	- (void)tearDown {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		[super tearDown];
	}

而这两个实例方法会在每个测试项开始测试和完成测试时调用。也就是说如果我们只有 `- (void)testExample1` 和 `- (void)testExample2`，整个时序是

	+ (void)setUp

	- (void)setUp
	- (void)testExample1
	- (void)tearDown

	- (void)setUp
	- (void)testExample2
	- (void)tearDown

	+ (void)tearDown

## 3 出现内存泄漏的例子

	@interface testMemoryTests : XCTestCase
	@property (nonatomic, strong) NSMutableArray *array;
	@end

	@implementation testMemoryTests

	- (void)setUp {
	    [super setUp];
	    self.array = [NSMutableArray array];
	}

	- (void)tearDown {
	    [self printMemory];
	    [super tearDown];
	}


	- (void)testExample1 {
	    
	    for (int i = 0; i < 1000000; i++) {
	        [self.array addObject:@(i)];
	    }
	}

	- (void)testExample2 {
	    for (int i = 0; i < 1000000; i++) {
	        [self.array addObject:@(i)];
	    }
	}

声明了一个可变数组，放在 `- (void)setUp` 中初始化然后在每个测试用例中使用。乍一看这种写法非常奇怪，但是在我们的自动化测试中就是写出了这样的代码。

	Test Suite 'Selected tests' started at 2017-10-21 12:30:04.346
	Test Suite 'testMemoryTests.xctest' started at 2017-10-21 12:30:04.347
	Test Suite 'testMemoryTests' started at 2017-10-21 12:30:04.347
	Test Case '-[testMemoryTests testExample1]' started.
	**2017-10-21 12:30:04.436841+0800 testMemory[11300:9897955] used memory is 84.203125**
	Test Case '-[testMemoryTests testExample1]' passed (0.089 seconds).
	Test Case '-[testMemoryTests testExample2]' started.
	**2017-10-21 12:30:04.537058+0800 testMemory[11300:9897955] used memory is 93.027344**
	Test Case '-[testMemoryTests testExample2]' passed (0.100 seconds).
	Test Case '-[testMemoryTests testExample3]' started.
	**2017-10-21 12:30:04.621553+0800 testMemory[11300:9897955] used memory is 101.734375**
	Test Case '-[testMemoryTests testExample3]' passed (0.084 seconds).
	Test Suite 'testMemoryTests' passed at 2017-10-21 12:30:04.622.
		 Executed 3 tests, with 0 failures (0 unexpected) in 0.273 (0.275) seconds
	Test Suite 'testMemoryTests.xctest' passed at 2017-10-21 12:30:04.623.
		 Executed 3 tests, with 0 failures (0 unexpected) in 0.273 (0.276) seconds
	Test Suite 'Selected tests' passed at 2017-10-21 12:30:04.623.
		 Executed 3 tests, with 0 failures (0 unexpected) in 0.273 (0.277) seconds

可以看到在运行 testExample2、testExample3 完毕之后内存是在上升的，根据 ARC 的语法规则 `- (void)setUp` 中对变量重新赋值之后，之前的那个对象没有人持有引用计数为零内存应该会被回收，不应该出现内存增加的情况。内存怎么没有被回收呢？
当我们在 `- (void)tearDown` 中把对象置为 nil 之后呢？

	- (void)tearDown {
	    self.array = nil;
	    [self printMemory];
	    [super tearDown];
	}

	Test Suite 'Selected tests' started at 2017-10-21 12:32:47.889
	Test Suite 'testMemoryTests.xctest' started at 2017-10-21 12:32:47.889
	Test Suite 'testMemoryTests' started at 2017-10-21 12:32:47.890
	Test Case '-[testMemoryTests testExample1]' started.
	2017-10-21 12:32:47.969078+0800 testMemory[11345:9899718] used memory is 84.203125 
	Test Case '-[testMemoryTests testExample1]' passed (0.082 seconds).
	Test Case '-[testMemoryTests testExample2]' started.
	2017-10-21 12:32:48.085447+0800 testMemory[11345:9899718] used memory is 84.406250 
	Test Case '-[testMemoryTests testExample2]' passed (0.113 seconds).
	Test Case '-[testMemoryTests testExample3]' started.
	2017-10-21 12:32:48.167272+0800 testMemory[11345:9899718] used memory is 84.523438 
	Test Case '-[testMemoryTests testExample3]' passed (0.081 seconds).
	Test Suite 'testMemoryTests' passed at 2017-10-21 12:32:48.168.
		 Executed 3 tests, with 0 failures (0 unexpected) in 0.276 (0.278) seconds
	Test Suite 'testMemoryTests.xctest' passed at 2017-10-21 12:32:48.168.
		 Executed 3 tests, with 0 failures (0 unexpected) in 0.276 (0.279) seconds
	Test Suite 'Selected tests' passed at 2017-10-21 12:32:48.169.
		 Executed 3 tests, with 0 failures (0 unexpected) in 0.276 (0.280) seconds

难道对 ARC 的理解还是有偏差？

## 4 提出猜想尝试合理解释

### 猜想一
统计内存的结果有偏差。

> - Free Memory：未使用的 RAM 容量，随时可以被应用分配使用
> - Wired Memory：用来存放内核代码和数据结构，它主要为内核服务，如负责网络、文件系统之类的；对于应用、framework、一些用户级别的软件是没办法分配此内存的。但是应用程序也会对 Wired Memory 的分配有所影响。
> - Active Memory：活跃的内存，正在被使用或很短时间内被使用过
> - Inactive Memory：最近被使用过，但是目前处于不活跃状态

这块儿的总结来自 [让人懵逼的 iOS 系统内存分配问题](http://www.jianshu.com/p/fcbb9a472633)。难道是快速的运行过程中，第一块对象所指向的内存块在没有被引用的时候被标记成了可用内存，但还是属于`Active Memory`？于是统计的结果包含被有对象指向和没被对象指向（但在很短的时间内被使用过）的内存？难道是时间间隔太短了，操作系统都还来不及把第一块儿内存释放掉？操作系统是不是有一套复杂的内存缓存算法，时间太短，这块儿本应该被回收的内存暂时还没被回收？
在跟同事讨论的时候，我甚至现场瞎扯了一段 malloc 为了避免内存碎片发生，所以每次新开辟内存的时候找个大点的地方而不是在刚才的位置开辟。

[       A        ][    B   ][                 C                  ][                   D                          ]

假如 A 是第一个 array 所指向的内存块儿，B 是未被分配的内存， C 被分配，D 未被分配。当第二次开辟内存时，A 还未被回收。因为 B 太小，重新再 D 的位置开个内存满足需求。当上述过程一直被重复，重复到最后没存不够用。
那如何解释置为 nil 之后内存问题解决呢？我解释为置为 nil 之后 A 立马被清除，所有比特位设置为 0，操作系统将 AB 合并成一个较大的空闲块儿。


为了验证，采取在每个 example 之前 sleep 几秒，看看操作系统是不是会有足够时间回收内存？结果很不幸，猜想一不对。

### 猜想二
难道每次 `- (void)setUp` 的时候新起了一个进程？
之所以这么猜测，是通过在 `self.array = [NSMutableArray array];` 断点发现重新赋值之前 self.array 是 nil。
![](http://oofm3g268.bkt.clouddn.com/%E5%B1%8F%E5%B9%95%E5%BF%AB%E7%85%A7%202017-10-21%20%E4%B8%8B%E5%8D%881.00.46.png)

这个真是一脸懵逼。判断这个猜想很简单，看一下 pid 就行了。日志里的 `2017-10-21 12:32:48.085447+0800 testMemory[11345:9899718] used memory is 84.406250 0` [11345:9899718] 冒号签名的数字就是 pid，后面的一个不清楚是什么。显然是属于同一个进程。

到这里，所有猜想都破灭。

## 5 求助 Google

先看下 Apple 的文档对此有没有作出解释或者忠告，反正我是没找着。Stack Overflow 也没看到类似的问题。最后找到一个外国人写的博客 [I’m Pretty Sure Most of Us Are Wrong about XCTestCase tearDown…](https://qualitycoding.org/teardown/)，看着标题感觉就很接近我要找东西。这篇博客看完之后醍醐灌顶意犹未尽。

1. XCTest queries the runtime for XCTestCase / test method combinations. For each combination:
2. A new test case is instantiated, associated with a specific test method.
3. These are all aggregated into a collection.
4. XCTest iterates through this collection of test cases.

In other words, it builds up the entire set of XCTestCase instances before running a single test.

也就是说有多少个测试方法就会生成多少个 XCTestCase 的实例，当然 array 资源就会申请多份。在跑一个测试之前，系统会生成整个 XCTestCase 实例集合？对此模模糊糊有点明白是咋回事了。

## 6 看源码实现

在他的博客评论里有人提到可以看 Swift 怎么实现的 XCTest https://github.com/apple/swift-corelibs-xctest  
一下就更燃了。虽然 Swift 不咋看得懂，但是看个大概意思还是可以的。

	internal class XCTestCaseSuite: XCTestSuite {
	    private let testCaseClass: XCTestCase.Type?

	    init(testCaseEntry: XCTestCaseEntry) {
	        let testCaseClass = testCaseEntry.testCaseClass
	        self.testCaseClass = testCaseClass
	        super.init(name: String(describing: testCaseClass))

	        for (testName, testClosure) in testCaseEntry.allTests {
	            let testCase = .init(name: testName, testClosure: testClosure)
	            addTest(testCase)
	        }
	    }

	    override func setUp() {
	        if let testCaseClass = testCaseClass {
	            testCaseClass.setUp()
	        }
	    }

	    override func tearDown() {
	        if let testCaseClass = testCaseClass {
	            testCaseClass.tearDown()
	        }
	    }
	}

这里就看到了 XCTestCaseSuite 这个类的构造函数里把输入的所有测试项遍历了一遍，调用父类的父类 `XCTestCase` 的构造方法传入 test 的名字和执行块儿，并加入了父类 XCTestSuite 的一个数组里。

	open class XCTestSuite: XCTest {
	    open private(set) var tests = [XCTest]()// 存放 XCTestCase 实例的数组，每个元素是一个新的 XCTestCase 实例，只不过用不同的 test 方法和方法体初始化

	    /// The name of this test suite.
	    open override var name: String {
	        return _name
	    }
	    /// A private setter for the name of this test suite.
	    private let _name: String

	    /// The number of test cases in this suite.
	    open override var testCaseCount: Int {
	        return tests.reduce(0) { $0 + $1.testCaseCount }
	    }

	    open override var testRunClass: AnyClass? {
	        return XCTestSuiteRun.self
	    }

	    open override func perform(_ run: XCTestRun) {
	        guard let testRun = run as? XCTestSuiteRun else {
	            fatalError("Wrong XCTestRun class.")
	        }

	        run.start()
	        setUp() // XCTestCase 的类方法
	        for test in tests {
	            test.run()
	            testRun.addTestRun(test.testRun!) // 遍历数组，把每个 XCTestCase 实例取出来 run
	        }
	        tearDown() // XCTestCase 的类方法
	        run.stop()
	    }

	    public init(name: String) {
	        _name = name
	    }

	    /// Adds a test (either an `XCTestSuite` or an `XCTestCase` to this
	    /// collection.
	    open func addTest(_ test: XCTest) {
	        tests.append(test)
	    }
	}

也就是说在跑测试的时候会有一个 XCTestSuite 实例，它存放着用不同的 test 方法和方法体初始化来的 XCTestCase 实例（就是我们的 xxxx.m 文件指向的那个类）。XCTestSuite 实例拿着所有的 XCTestCase 遍历测试方法。这就彻底解释了内存问题。

