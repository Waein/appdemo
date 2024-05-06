package cn.byb.appdemo;

import cn.fraudmetrix.cache.jcache.JCacheFactory;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.stereotype.Component;

import javax.cache.Cache;
import javax.cache.CacheManager;
import javax.cache.configuration.MutableConfiguration;

@EnableCaching
@Component
public class CacheDemo {

    @Bean
    public MutableConfiguration<String, byte[]> mutableConfiguration() {
        return JCacheFactory.newDefaultConfiguration(String.class, byte[].class);
    }

    @Bean
    public Cache<String, byte[]> redisCache(CacheManager cacheManager) {
        // <!-- spring cache 注解驱动  -->
        // 类型要根据需要使用cachable的方法来设置，这里用String
        cacheManager.createCache("spring-cache",
                                 JCacheFactory.newDefaultConfiguration(String.class, String.class));
        return cacheManager.getCache("appdemo");
    }
}
