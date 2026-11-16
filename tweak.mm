#import <UIKit/UIKit.h>
#import <dlfcn.h>

#define API(name, ret, ...) static ret (*name)(__VA_ARGS__)
API(il2cpp_domain_get, void*, void);
API(il2cpp_thread_attach, void*, void*);
API(il2cpp_domain_assembly_open, void*, void*, const char*);
API(il2cpp_assembly_get_image, void*, void*);
API(il2cpp_class_from_name, void*, void*, const char*, const char*);
API(il2cpp_runtime_class_init, void, void*);
API(il2cpp_class_get_type, void*, void*);
API(il2cpp_type_get_object, void*, void*);
API(il2cpp_class_get_method_from_name, void**, void*, const char*, int);
API(il2cpp_class_get_field_from_name, void*, void*, const char*);
API(il2cpp_field_static_get_value, void, void*, void*);

static bool loadAPI() {
#define L(n) n = (decltype(n))dlsym(RTLD_DEFAULT, #n); if (!n) return false;
    L(il2cpp_domain_get) L(il2cpp_thread_attach) L(il2cpp_domain_assembly_open)
    L(il2cpp_assembly_get_image) L(il2cpp_class_from_name) L(il2cpp_runtime_class_init)
    L(il2cpp_class_get_type) L(il2cpp_type_get_object) L(il2cpp_class_get_method_from_name)
    L(il2cpp_class_get_field_from_name) L(il2cpp_field_static_get_value)
    return true;
}

static void *getImage(void *dom, const char *name) {
    void *a = il2cpp_domain_assembly_open(dom, name);
    return a ? il2cpp_assembly_get_image(a) : NULL;
}

static void openUI() {
    if (!loadAPI()) { NSLog(@"[T] thieu il2cpp export"); return; }
    void *dom = il2cpp_domain_get();
    il2cpp_thread_attach(dom);

    void *imgCS   = getImage(dom, "Assembly-CSharp");
    void *imgCore = getImage(dom, "UnityEngine.CoreModule");
    if (!imgCS || !imgCore) { NSLog(@"[T] thieu assembly"); return; }

    void *kMgr = il2cpp_class_from_name(imgCS, "", "UIMgr");
    void *kObj = il2cpp_class_from_name(imgCore, "UnityEngine", "Object");
    void *kTyp = il2cpp_class_from_name(imgCS, "", "UIType");
    if (!kMgr || !kObj || !kTyp) { NSLog(@"[T] thieu class"); return; }
    il2cpp_runtime_class_init(kMgr);
    il2cpp_runtime_class_init(kObj);
    il2cpp_runtime_class_init(kTyp);

    void *fTok = il2cpp_class_get_field_from_name(kTyp, "PlayerGM");
    if (!fTok) { NSLog(@"[T] thieu PlayerGM"); return; }
    void *token = NULL;
    il2cpp_field_static_get_value(fTok, &token);
    if (!token) { NSLog(@"[T] token null"); return; }

    void *typeObj = il2cpp_type_get_object(il2cpp_class_get_type(kMgr));
    void **miFind = il2cpp_class_get_method_from_name(kObj, "FindObjectOfType", 1);
    if (!miFind) { NSLog(@"[T] thieu FindObjectOfType"); return; }
    typedef void *(*Find_t)(void*, void*);
    void *mgr = ((Find_t)(*miFind))(typeObj, miFind);
    if (!mgr) { NSLog(@"[T] chua co UIMgr"); return; }

    void **miOpen = il2cpp_class_get_method_from_name(kMgr, "OpenUI", 1);
    if (!miOpen) { NSLog(@"[T] thieu OpenUI"); return; }
    typedef void *(*Open_t)(void*, void*, void*);
    void *r = ((Open_t)(*miOpen))(mgr, token, miOpen);
    NSLog(@"[T] OpenUI -> %p", r);
}

@interface TapHandler : NSObject
- (void)onTap:(UITapGestureRecognizer *)g;
@end
@implementation TapHandler
- (void)onTap:(UITapGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateRecognized) openUI();
}
@end

static TapHandler *handler;
static __weak UIWindow *attachedWindow;

static UIWindow *findWindow() {
    for (UIWindow *w in UIApplication.sharedApplication.windows)
        if (w.isKeyWindow) return w;
    return UIApplication.sharedApplication.windows.firstObject;
}

static void tryAttach() {
    UIWindow *w = findWindow();
    if (!w) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ tryAttach(); }); return; }
    if (w == attachedWindow) return;
    attachedWindow = w;
    handler = handler ?: [TapHandler new];
    UITapGestureRecognizer *g = [[UITapGestureRecognizer alloc] initWithTarget:handler action:@selector(onTap:)];
    g.numberOfTouchesRequired = 3;
    g.numberOfTapsRequired = 2;
    g.cancelsTouchesInView = NO;
    g.delaysTouchesBegan = NO;
    g.delaysTouchesEnded = NO;
    [w addGestureRecognizer:g];
    NSLog(@"[T] da gan cu chi 3 ngon x2");
}

__attribute__((constructor)) static void init() {
    dispatch_async(dispatch_get_main_queue(), ^{ tryAttach(); });
}
