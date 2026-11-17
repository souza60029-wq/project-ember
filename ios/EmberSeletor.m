// Seletor nativo do iPhone para o Ember: galeria de fotos (PHPicker) e explorador de arquivos
// (UIDocumentPicker). Conversa com o jogo por arquivos na pasta Documents/seletor:
//   pedido.json    (jogo -> nativo)  {"id":N,"origem":"galeria|arquivos","varios":true,"tipo":"imagem|audio|qualquer"}
//   resultado.json (nativo -> jogo)  {"id":N,"ok":true,"arquivos":["/caminho/..."]}  ou  {"id":N,"ok":false}
// Os arquivos escolhidos sao copiados para Documents/seletor/recebidos/.
// Este arquivo e adicionado ao projeto Xcode pelo GitHub Actions (ferramentas/adicionar_seletor_ios.rb).

#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *EmberDocumentos(void) {
	return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}

static NSString *EmberPasta(void) {
	return [EmberDocumentos() stringByAppendingPathComponent:@"seletor"];
}

@interface EmberSeletor : NSObject <UIDocumentPickerDelegate, PHPickerViewControllerDelegate>
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL ocupado;
@property (nonatomic, assign) NSInteger pedidoId;
@property (nonatomic, copy) NSString *destino;
+ (instancetype)compartilhado;
@end

@implementation EmberSeletor

+ (void)load {
	[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
													  object:nil
													   queue:[NSOperationQueue mainQueue]
												  usingBlock:^(NSNotification *nota) {
		[[EmberSeletor compartilhado] iniciar];
	}];
}

+ (instancetype)compartilhado {
	static EmberSeletor *unico = nil;
	static dispatch_once_t uma_vez;
	dispatch_once(&uma_vez, ^{ unico = [[EmberSeletor alloc] init]; });
	return unico;
}

- (void)iniciar {
	[[NSFileManager defaultManager] createDirectoryAtPath:EmberPasta() withIntermediateDirectories:YES attributes:nil error:nil];
	self.timer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(checar) userInfo:nil repeats:YES];
}

- (void)checar {
	if (self.ocupado) {
		return;
	}
	NSString *arquivo = [EmberPasta() stringByAppendingPathComponent:@"pedido.json"];
	NSData *dados = [NSData dataWithContentsOfFile:arquivo];
	if (dados == nil) {
		return;
	}
	[[NSFileManager defaultManager] removeItemAtPath:arquivo error:nil]; // o jogo usa isso como "recebi"
	id obj = [NSJSONSerialization JSONObjectWithData:dados options:0 error:nil];
	if (![obj isKindOfClass:[NSDictionary class]]) {
		return;
	}
	NSDictionary *pedido = (NSDictionary *)obj;
	self.ocupado = YES;
	self.pedidoId = [pedido[@"id"] integerValue];
	NSString *origem = [pedido[@"origem"] isKindOfClass:[NSString class]] ? pedido[@"origem"] : @"arquivos";
	NSString *tipo = [pedido[@"tipo"] isKindOfClass:[NSString class]] ? pedido[@"tipo"] : @"qualquer";
	BOOL varios = [pedido[@"varios"] boolValue];
	self.destino = [EmberPasta() stringByAppendingPathComponent:@"recebidos"];
	[[NSFileManager defaultManager] createDirectoryAtPath:self.destino withIntermediateDirectories:YES attributes:nil error:nil];

	UIViewController *topo = [self controladorTopo];
	if (topo == nil) {
		[self finalizar:@[] cancelado:NO erro:@"Nao achei a tela do app para abrir o seletor."];
		return;
	}
	if ([origem isEqualToString:@"galeria"]) {
		if (@available(iOS 14.0, *)) {
			PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
			config.selectionLimit = varios ? 0 : 1;
			config.filter = [PHPickerFilter imagesFilter];
			PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
			picker.delegate = self;
			[topo presentViewController:picker animated:YES completion:nil];
			return;
		}
	}
	NSArray *tipos = @[@"public.item"];
	if ([tipo isEqualToString:@"imagem"]) {
		tipos = @[@"public.image"];
	} else if ([tipo isEqualToString:@"audio"]) {
		tipos = @[@"public.audio"];
	}
	UIDocumentPickerViewController *doc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:tipos inMode:UIDocumentPickerModeImport];
	doc.allowsMultipleSelection = varios;
	doc.delegate = self;
	[topo presentViewController:doc animated:YES completion:nil];
}

- (UIViewController *)controladorTopo {
	UIWindow *janela = nil;
	for (UIWindow *w in [UIApplication sharedApplication].windows) {
		if (w.isKeyWindow) {
			janela = w;
			break;
		}
	}
	if (janela == nil) {
		janela = [UIApplication sharedApplication].windows.firstObject;
	}
	UIViewController *vc = janela.rootViewController;
	while (vc.presentedViewController != nil) {
		vc = vc.presentedViewController;
	}
	return vc;
}

// Caminho livre dentro da pasta de destino (se ja existe, acrescenta _1, _2...).
- (NSString *)caminhoLivre:(NSString *)nome {
	@synchronized (self) {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *base = [nome stringByDeletingPathExtension];
		NSString *ext = [nome pathExtension];
		NSString *caminho = [self.destino stringByAppendingPathComponent:nome];
		int n = 1;
		while ([fm fileExistsAtPath:caminho]) {
			NSString *novo = ext.length > 0 ? [NSString stringWithFormat:@"%@_%d.%@", base, n, ext] : [NSString stringWithFormat:@"%@_%d", base, n];
			caminho = [self.destino stringByAppendingPathComponent:novo];
			n++;
		}
		[fm createFileAtPath:caminho contents:[NSData data] attributes:nil]; // reserva o nome
		return caminho;
	}
}

- (void)finalizar:(NSArray<NSString *> *)arquivos cancelado:(BOOL)cancelado erro:(NSString *)erro {
	NSMutableDictionary *r = [NSMutableDictionary dictionary];
	r[@"id"] = @(self.pedidoId);
	r[@"ok"] = @(!cancelado && erro == nil && arquivos.count > 0);
	r[@"arquivos"] = arquivos ?: @[];
	if (erro != nil) {
		r[@"erro"] = erro;
	}
	NSData *json = [NSJSONSerialization dataWithJSONObject:r options:0 error:nil];
	NSString *tmp = [EmberPasta() stringByAppendingPathComponent:@"resultado.tmp"];
	NSString *final = [EmberPasta() stringByAppendingPathComponent:@"resultado.json"];
	[json writeToFile:tmp atomically:YES];
	[[NSFileManager defaultManager] removeItemAtPath:final error:nil];
	[[NSFileManager defaultManager] moveItemAtPath:tmp toPath:final error:nil];
	self.ocupado = NO;
}

#pragma mark - Explorador de arquivos

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
	NSMutableArray<NSString *> *saidas = [NSMutableArray array];
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSURL *url in urls) {
		BOOL acesso = [url startAccessingSecurityScopedResource];
		NSString *destino = [self caminhoLivre:url.lastPathComponent];
		[fm removeItemAtPath:destino error:nil];
		if ([fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:destino] error:nil]) {
			[saidas addObject:destino];
		}
		if (acesso) {
			[url stopAccessingSecurityScopedResource];
		}
	}
	[self finalizar:saidas cancelado:NO erro:(saidas.count == 0 ? @"Nao consegui copiar o arquivo escolhido." : nil)];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
	[self finalizar:@[] cancelado:YES erro:nil];
}

#pragma mark - Galeria de fotos

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)) {
	[picker dismissViewControllerAnimated:YES completion:nil];
	if (results.count == 0) {
		[self finalizar:@[] cancelado:YES erro:nil];
		return;
	}
	NSMutableArray<NSString *> *saidas = [NSMutableArray array];
	dispatch_group_t grupo = dispatch_group_create();
	for (PHPickerResult *resultado in results) {
		NSItemProvider *prov = resultado.itemProvider;
		NSString *nome = prov.suggestedName.length > 0 ? prov.suggestedName : @"imagem";
		NSString *uti = nil;
		if ([prov hasItemConformingToTypeIdentifier:@"public.png"]) {
			uti = @"public.png";
		} else if ([prov hasItemConformingToTypeIdentifier:@"public.jpeg"]) {
			uti = @"public.jpeg";
		}
		dispatch_group_enter(grupo);
		if (uti != nil) {
			NSString *ext = [uti isEqualToString:@"public.png"] ? @"png" : @"jpg";
			[prov loadFileRepresentationForTypeIdentifier:uti completionHandler:^(NSURL *url, NSError *erro) {
				if (url != nil) {
					NSString *arquivo = [[nome stringByDeletingPathExtension] stringByAppendingPathExtension:ext];
					NSString *destino = [self caminhoLivre:arquivo];
					NSFileManager *fm = [NSFileManager defaultManager];
					[fm removeItemAtPath:destino error:nil];
					if ([fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:destino] error:nil]) {
						@synchronized (saidas) { [saidas addObject:destino]; }
					}
				}
				dispatch_group_leave(grupo);
			}];
		} else if ([prov canLoadObjectOfClass:[UIImage class]]) {
			// formatos como HEIC: converte para PNG
			[prov loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading> obj, NSError *erro) {
				UIImage *img = (UIImage *)obj;
				NSData *png = img != nil ? UIImagePNGRepresentation(img) : nil;
				if (png != nil) {
					NSString *destino = [self caminhoLivre:[[nome stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"]];
					if ([png writeToFile:destino atomically:YES]) {
						@synchronized (saidas) { [saidas addObject:destino]; }
					}
				}
				dispatch_group_leave(grupo);
			}];
		} else {
			dispatch_group_leave(grupo);
		}
	}
	dispatch_group_notify(grupo, dispatch_get_main_queue(), ^{
		[saidas sortUsingSelector:@selector(localizedStandardCompare:)];
		[self finalizar:saidas cancelado:NO erro:(saidas.count == 0 ? @"Nao consegui ler a foto escolhida." : nil)];
	});
}

@end
